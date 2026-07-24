import Foundation

struct BootstrapConfiguration: Equatable, Codable {
    var ontHost: String = "192.168.100.1"

    var webUsername: String = "admin"
    var webPassword: String = "adminHW"

    var pppoeUsername: String = "yaraacs"
    var pppoePassword: String = "yaraacs"
    var vlanID: String = "800"

    var acsURL: String = "https://yaraacs.tci.ir"
    var acsUsername: String = "yaraacs"
    var acsPassword: String = "yaraacs"
    var informInterval: String = "30"

    var telnetUsername: String = "root"
    var telnetPasswordsText: String = "adminHW\nadmin"
    var telnetOnly: Bool = false
    var enableRemoteAccessPage: Bool = true

    var telnetPasswords: [String] {
        telnetPasswordsText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func url(path: String, scheme: String = "http") -> URL? {
        let normalizedPath = path.hasPrefix("/") ? path : "/" + path
        return URL(string: "\(scheme)://\(ontHost)\(normalizedPath)")
    }
}

enum BootstrapStage: String, CaseIterable, Identifiable {
    case idle
    case reachability
    case login
    case lan
    case wan
    case acs
    case remoteAccess
    case telnet
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idle:
            return "آماده"
        case .reachability:
            return "بررسی اتصال لایه ۳"
        case .login:
            return "ورود به مودم"
        case .lan:
            return "فعال‌سازی LAN"
        case .wan:
            return "ساخت WAN VLAN 800"
        case .acs:
            return "تنظیم ACS"
        case .remoteAccess:
            return "فعال‌سازی Telnet/SSH محلی"
        case .telnet:
            return "ثبت کانفیگ پیش‌فرض"
        case .done:
            return "تمام شد"
        }
    }

    var progressValue: Double {
        guard self != .idle else { return 0 }
        let ordered = BootstrapStage.allCases.filter { $0 != .idle }
        guard let index = ordered.firstIndex(of: self) else { return 0 }
        return Double(index + 1) / Double(ordered.count)
    }
}
