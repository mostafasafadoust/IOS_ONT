import Foundation
import Network

final class TelnetClient {
    private let host: String
    private let port: UInt16
    private let queue = DispatchQueue(label: "ir.tivan.ont.telnet")
    private var connection: NWConnection?
    private var buffer = ""
    private var waiters: [Waiter] = []

    private struct Waiter {
        let patterns: [String]
        let deadline: Date
        let continuation: CheckedContinuation<String, Error>
    }

    init(host: String, port: UInt16 = 23) {
        self.host = host
        self.port = port
    }

    deinit {
        close()
    }

    func runDefaultConfig(configuration: BootstrapConfiguration) async throws -> String {
        try await connect(timeout: 12)
        defer { close() }

        _ = try await waitForAny(
            ["login:", "Login:", "Username:", "ONT login:", "Password:", "password:"],
            timeout: 14
        )

        var authenticated = false

        for password in configuration.telnetPasswords {
            await clearBuffer()
            try await sendLine(configuration.telnetUsername)
            _ = try await waitForAny(["Password:", "password:"], timeout: 6)
            await clearBuffer()
            try await sendLine(password)
            let transcript = try await waitForAny(
                ["WAP>", "SU_WAP>", "#", "$", "success!", "Login incorrect", "incorrect", "login:"],
                timeout: 8
            )
            if transcript.localizedCaseInsensitiveContains("incorrect") ||
                transcript.localizedCaseInsensitiveContains("login:") {
                continue
            }
            authenticated = true
            break
        }

        guard authenticated else {
            throw BootstrapError.telnetLoginFailed
        }

        try await enterShell(possiblePasswords: configuration.telnetPasswords)

        let commands = [
            "cd /mnt/jffs2",
            "cp -f hw_ctree.xml hw_default_ctree.xml",
            "chmod 644 hw_default_ctree.xml",
            "sync",
            "cmp hw_ctree.xml hw_default_ctree.xml && echo TIVAN_CMP_OK || echo TIVAN_CMP_FAIL",
            "md5sum hw_ctree.xml hw_default_ctree.xml"
        ]

        var finalTranscript = ""
        for command in commands {
            await clearBuffer()
            try await sendLine(command)
            let transcript = try await waitForAny(
                ["WAP>", "SU_WAP>", "#", "$", "TIVAN_CMP_OK", "TIVAN_CMP_FAIL"],
                timeout: 12
            )
            if command.contains("TIVAN_CMP_OK") {
                finalTranscript = transcript
            }
        }

        guard finalTranscript.contains("TIVAN_CMP_OK") else {
            throw BootstrapError.telnetPromptNotFound(finalTranscript)
        }

        return finalTranscript
    }

    private func enterShell(possiblePasswords: [String]) async throws {
        await clearBuffer()
        try await sendLine("su")
        let suTranscript = try await waitForAny(["Password:", "password:", "success!", "SU_WAP>", "#", "$", "WAP>"], timeout: 8)
        if suTranscript.localizedCaseInsensitiveContains("password") {
            await clearBuffer()
            try await sendLine(possiblePasswords.first ?? "adminHW")
            _ = try await waitForAny(["success!", "SU_WAP>", "#", "$", "WAP>"], timeout: 8)
        }

        await clearBuffer()
        try await sendLine("shell")
        let shellTranscript = try await waitForAny(
            ["WAP>", "SU_WAP>", "Dopra Linux", "#", "$", "shell_prompt"],
            timeout: 8
        )
        if shellTranscript.contains("WAP>") ||
            shellTranscript.contains("SU_WAP>") ||
            shellTranscript.contains("#") ||
            shellTranscript.contains("$") ||
            shellTranscript.localizedCaseInsensitiveContains("dopra") {
            return
        }

        throw BootstrapError.telnetPromptNotFound(shellTranscript)
    }

    private func connect(timeout: TimeInterval) async throws {
        let endpointHost = NWEndpoint.Host(host)
        guard let endpointPort = NWEndpoint.Port(rawValue: port) else {
            throw BootstrapError.connectionFailed("پورت Telnet نامعتبر است: \(port)")
        }
        let connection = NWConnection(host: endpointHost, port: endpointPort, using: .tcp)
        self.connection = connection

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var didResume = false
            func resume(_ result: Result<Void, Error>) {
                guard !didResume else { return }
                didResume = true
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            connection.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.startReceiveLoop()
                    resume(.success(()))
                case .failed(let error):
                    resume(.failure(error))
                case .cancelled:
                    resume(.failure(BootstrapError.connectionFailed("اتصال Telnet لغو شد.")))
                default:
                    break
                }
            }

            connection.start(queue: queue)

            queue.asyncAfter(deadline: .now() + timeout) {
                resume(.failure(BootstrapError.timeout("Telnet connect \(self.host):\(self.port)")))
            }
        }
    }

    private func clearBuffer() async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.async {
                self.buffer.removeAll()
                continuation.resume()
            }
        }
    }

    private func close() {
        queue.async { [connection] in
            connection?.cancel()
        }
    }

    private func sendLine(_ line: String) async throws {
        let payload = line + "\r\n"
        guard let data = payload.data(using: .utf8) else { return }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [connection] in
                guard let connection else {
                    continuation.resume(throwing: BootstrapError.connectionFailed("اتصال Telnet بسته است."))
                    return
                }
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                })
            }
        }
    }

    private func waitForAny(_ patterns: [String], timeout: TimeInterval) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            queue.async {
                if self.bufferContains(patterns) {
                    continuation.resume(returning: self.buffer)
                    return
                }

                let waiter = Waiter(
                    patterns: patterns,
                    deadline: Date().addingTimeInterval(timeout),
                    continuation: continuation
                )
                self.waiters.append(waiter)
                self.scheduleWaiterTimeouts()
            }
        }
    }

    private func startReceiveLoop() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { [weak self] data, _, isComplete, error in
            guard let self else { return }
            if let data, !data.isEmpty {
                self.queue.async {
                    self.append(data)
                    self.resolveWaiters()
                }
            }
            if isComplete || error != nil {
                self.queue.async {
                    let error = error ?? BootstrapError.connectionFailed("اتصال Telnet بسته شد.")
                    self.failWaiters(error)
                }
                return
            }
            self.startReceiveLoop()
        }
    }

    private func append(_ data: Data) {
        let clean = stripTelnetCommands(from: data)
        guard let chunk = String(data: clean, encoding: .utf8) ??
                String(data: clean, encoding: .ascii) else {
            return
        }
        buffer += chunk
        if buffer.count > 48_000 {
            buffer.removeFirst(buffer.count - 48_000)
        }
    }

    private func stripTelnetCommands(from data: Data) -> Data {
        var output = Data()
        let bytes = [UInt8](data)
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == 255 {
                guard index + 1 < bytes.count else { break }
                let command = bytes[index + 1]
                if command == 255 {
                    output.append(255)
                    index += 2
                } else if [UInt8(251), UInt8(252), UInt8(253), UInt8(254)].contains(command), index + 2 < bytes.count {
                    index += 3
                } else {
                    index += 2
                }
            } else {
                output.append(byte)
                index += 1
            }
        }
        return output
    }

    private func resolveWaiters() {
        var remaining: [Waiter] = []
        for waiter in waiters {
            if bufferContains(waiter.patterns) {
                waiter.continuation.resume(returning: buffer)
            } else if Date() > waiter.deadline {
                waiter.continuation.resume(throwing: BootstrapError.timeout(waiter.patterns.joined(separator: " | ")))
            } else {
                remaining.append(waiter)
            }
        }
        waiters = remaining
    }

    private func failWaiters(_ error: Error) {
        let pending = waiters
        waiters.removeAll()
        for waiter in pending {
            waiter.continuation.resume(throwing: error)
        }
    }

    private func scheduleWaiterTimeouts() {
        guard !waiters.isEmpty else { return }
        queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.resolveWaiters()
            self?.scheduleWaiterTimeouts()
        }
    }

    private func bufferContains(_ patterns: [String]) -> Bool {
        patterns.contains { pattern in
            buffer.range(of: pattern, options: [.caseInsensitive, .diacriticInsensitive]) != nil
        }
    }

}
