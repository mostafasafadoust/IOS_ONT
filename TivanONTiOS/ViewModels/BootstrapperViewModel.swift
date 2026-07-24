import Foundation

@MainActor
final class BootstrapperViewModel: ObservableObject {
    @Published var configuration = BootstrapConfiguration()
    @Published private(set) var stage: BootstrapStage = .idle
    @Published private(set) var events: [BootstrapEvent] = []
    @Published private(set) var isRunning = false
    @Published private(set) var succeeded: Bool?

    var progress: Double {
        stage.progressValue
    }

    var statusTitle: String {
        stage.title
    }

    func start(using webSession: HuaweiWebSession) {
        guard !isRunning else { return }
        isRunning = true
        succeeded = nil
        events.removeAll()
        let configuration = configuration

        Task {
            do {
                try await run(configuration: configuration, webSession: webSession)
                log(.success, "عملیات با موفقیت تمام شد.")
                stage = .done
                succeeded = true
            } catch {
                log(.error, error.localizedDescription)
                succeeded = false
            }
            isRunning = false
        }
    }

    func reset() {
        guard !isRunning else { return }
        stage = .idle
        succeeded = nil
        events.removeAll()
    }

    private func run(configuration: BootstrapConfiguration, webSession: HuaweiWebSession) async throws {
        if !configuration.telnetOnly {
            stage = .reachability
            let base = try await webSession.probe(configuration)
            log(.success, "مودم پاسخ داد: \(base)")

            stage = .login
            let login = try await webSession.login(configuration)
            log(.success, "ورود به پنل انجام شد. \(login.compactSummary)")

            stage = .lan
            do {
                let lan = try await webSession.enableLANPorts(configuration)
                log(.success, "LANها بررسی/فعال شدند. \(lan.compactSummary)")
            } catch {
                log(.warning, "مرحله LAN رد شد: \(error.localizedDescription)")
            }

            stage = .wan
            let wan = try await webSession.configureWAN(configuration)
            log(.success, "WAN ساخته/تنظیم شد. \(wan.compactSummary)")

            stage = .acs
            let acs = try await webSession.configureACS(configuration)
            log(.success, "ACS تنظیم شد. \(acs.compactSummary)")

            if configuration.enableRemoteAccessPage {
                stage = .remoteAccess
                do {
                    let remote = try await webSession.enableRemoteAccess(configuration)
                    log(.success, "Telnet/SSH محلی بررسی شد. \(remote.compactSummary)")
                } catch {
                    log(.warning, "صفحه Telnet/SSH قابل تنظیم نبود؛ اگر Telnet از قبل باز باشد ادامه می‌دهیم. \(error.localizedDescription)")
                }
            }
        }

        stage = .telnet
        let transcript = try await TelnetClient(host: configuration.ontHost).runDefaultConfig(configuration: configuration)
        let tail = transcript
            .split(separator: "\n")
            .suffix(10)
            .joined(separator: " | ")
        log(.success, "hw_default_ctree.xml با hw_ctree.xml برابر شد. \(tail)")
    }

    private func log(_ level: BootstrapEventLevel, _ message: String) {
        events.append(BootstrapEvent(level: level, message))
    }
}
