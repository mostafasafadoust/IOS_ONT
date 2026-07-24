import Foundation
import WebKit

@MainActor
final class HuaweiWebSession: NSObject, ObservableObject {
    private weak var webView: WKWebView?
    private var loadContinuation: CheckedContinuation<Void, Error>?
    private var loadTimeoutTask: Task<Void, Never>?
    private var allowedHost = "192.168.100.1"
    private(set) var activeScheme = "http"

    func attach(_ webView: WKWebView) {
        self.webView = webView
        webView.navigationDelegate = self
    }

    func probe(_ configuration: BootstrapConfiguration) async throws -> String {
        allowedHost = configuration.ontHost
        let paths = ["/index.asp", "/"]
        var lastError: Error?

        for scheme in ["http", "https"] {
            for path in paths {
                guard let url = configuration.url(path: path, scheme: scheme) else {
                    continue
                }
                do {
                    try await load(url, timeout: 14)
                    activeScheme = scheme
                    return "\(scheme)://\(configuration.ontHost)"
                } catch {
                    lastError = error
                }
            }
        }

        throw lastError ?? BootstrapError.connectionFailed("مودم روی \(configuration.ontHost) پاسخ نداد.")
    }

    func login(_ configuration: BootstrapConfiguration) async throws -> ScriptResult {
        _ = try await probe(configuration)
        let before = try await evaluateScriptResult(JavaScriptPayloads.loginState)
        if before.logged == true {
            return before
        }

        let submitted = try await evaluateScriptResult(
            JavaScriptPayloads.login(username: configuration.webUsername, password: configuration.webPassword)
        )
        if submitted.result?.ok != true {
            throw BootstrapError.scriptFailed(submitted.compactSummary)
        }

        try await Task.sleep(nanoseconds: 1_600_000_000)
        let after = try await evaluateScriptResult(JavaScriptPayloads.loginState)
        guard after.logged == true else {
            throw BootstrapError.scriptFailed("ورود به پنل مودم تایید نشد. \(after.compactSummary)")
        }
        return after
    }

    func enableLANPorts(_ configuration: BootstrapConfiguration) async throws -> ScriptResult {
        let paths = [
            "/html/bbsp/layer3/layer3.asp",
            "/html/ssmp/mainupportcfg/mainupportconfig.asp",
            "/html/ssmp/accoutcfg/ontmngt.asp"
        ]
        try await loadFirstWorkingPath(paths, configuration: configuration)
        let result = try await evaluateScriptResult(JavaScriptPayloads.enableLANPorts)
        guard result.succeeded else {
            throw BootstrapError.scriptFailed(result.compactSummary)
        }
        return result
    }

    func configureWAN(_ configuration: BootstrapConfiguration) async throws -> ScriptResult {
        let paths = [
            "/html/bbsp/wan/wan.asp",
            "/html/bbsp/layer3/layer3.asp"
        ]
        try await loadFirstWorkingPath(paths, configuration: configuration)
        let result = try await evaluateScriptResult(JavaScriptPayloads.configureWAN(configuration))
        guard result.succeeded else {
            throw BootstrapError.scriptFailed(result.compactSummary)
        }
        return result
    }

    func configureACS(_ configuration: BootstrapConfiguration) async throws -> ScriptResult {
        let paths = [
            "/html/ssmp/tr069/tr069.asp",
            "/html/AllUsers/html/ssmp/accoutcfg/ontmngt.asp"
        ]
        try await loadFirstWorkingPath(paths, configuration: configuration)
        let result = try await evaluateScriptResult(JavaScriptPayloads.configureACS(configuration))
        guard result.succeeded else {
            throw BootstrapError.scriptFailed(result.compactSummary)
        }

        let apply = try await evaluateScriptResult(JavaScriptPayloads.clickApply)
        guard apply.succeeded else {
            throw BootstrapError.scriptFailed(apply.compactSummary)
        }
        return result
    }

    func enableRemoteAccess(_ configuration: BootstrapConfiguration) async throws -> ScriptResult {
        let paths = [
            "/html/ssmp/telnet/telnet.asp",
            "/html/ssmp/ssh/ssh.asp",
            "/html/ssmp/stelnet/stelnet.asp",
            "/html/ssmp/remote/remote.asp",
            "/html/ssmp/remoteaccess/remoteaccess.asp",
            "/html/ssmp/security/remoteaccess.asp",
            "/html/bbsp/security/remoteaccess.asp",
            "/html/ssmp/servicecontrol/servicecontrol.asp",
            "/html/ssmp/servicecontrol/service.asp",
            "/html/bbsp/security/servicecontrol.asp"
        ]

        var lastError: Error?
        for path in paths {
            do {
                try await loadPath(path, configuration: configuration)
                let result = try await evaluateScriptResult(JavaScriptPayloads.enableRemoteAccess)
                if result.succeeded {
                    return result
                }
                lastError = BootstrapError.scriptFailed(result.compactSummary)
            } catch {
                lastError = error
            }
        }

        throw lastError ?? BootstrapError.scriptFailed("صفحه Telnet/SSH پیدا نشد.")
    }

    private func loadFirstWorkingPath(_ paths: [String], configuration: BootstrapConfiguration) async throws {
        var lastError: Error?
        for path in paths {
            do {
                try await loadPath(path, configuration: configuration)
                return
            } catch {
                lastError = error
            }
        }
        throw lastError ?? BootstrapError.invalidURL(paths.joined(separator: ", "))
    }

    private func loadPath(_ path: String, configuration: BootstrapConfiguration) async throws {
        guard let url = configuration.url(path: path, scheme: activeScheme) else {
            throw BootstrapError.invalidURL(path)
        }
        try await load(url, timeout: 14)
        try await Task.sleep(nanoseconds: 350_000_000)
    }

    private func load(_ url: URL, timeout: TimeInterval) async throws {
        guard let webView else {
            throw BootstrapError.webViewNotAttached
        }

        loadTimeoutTask?.cancel()
        loadContinuation = nil

        try await withCheckedThrowingContinuation { continuation in
            loadContinuation = continuation
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
            request.timeoutInterval = timeout
            webView.load(request)

            loadTimeoutTask = Task { [weak self] in
                let delay = UInt64(timeout * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
                await self?.finishLoad(.failure(BootstrapError.timeout(url.absoluteString)))
            }
        }
    }

    private func finishLoad(_ result: Result<Void, Error>) {
        guard let continuation = loadContinuation else { return }
        loadContinuation = nil
        loadTimeoutTask?.cancel()
        loadTimeoutTask = nil

        switch result {
        case .success:
            continuation.resume()
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }

    private func evaluateScriptResult(_ script: String) async throws -> ScriptResult {
        let raw = try await evaluate(script)
        guard let json = raw as? String else {
            throw BootstrapError.invalidJavaScriptResult
        }
        guard let data = json.data(using: .utf8) else {
            throw BootstrapError.invalidJavaScriptResult
        }
        return try JSONDecoder().decode(ScriptResult.self, from: data)
    }

    private func evaluate(_ script: String) async throws -> Any? {
        guard let webView else {
            throw BootstrapError.webViewNotAttached
        }
        return try await webView.callAsyncJavaScript(
            "return await \(script)",
            arguments: [:],
            in: nil,
            contentWorld: .page
        )
    }
}

extension HuaweiWebSession: WKNavigationDelegate {
    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            finishLoad(.success(()))
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            finishLoad(.failure(error))
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Task { @MainActor in
            finishLoad(.failure(error))
        }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        Task { @MainActor in
            guard challenge.protectionSpace.host == allowedHost,
                  let trust = challenge.protectionSpace.serverTrust else {
                completionHandler(.performDefaultHandling, nil)
                return
            }
            completionHandler(.useCredential, URLCredential(trust: trust))
        }
    }
}
