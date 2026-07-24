import Foundation

enum BootstrapEventLevel: String, Codable {
    case info
    case success
    case warning
    case error
}

struct BootstrapEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let level: BootstrapEventLevel
    let message: String

    init(level: BootstrapEventLevel = .info, _ message: String) {
        self.id = UUID()
        self.date = Date()
        self.level = level
        self.message = message
    }
}

enum BootstrapError: LocalizedError {
    case webViewNotAttached
    case timeout(String)
    case invalidURL(String)
    case invalidJavaScriptResult
    case scriptFailed(String)
    case telnetLoginFailed
    case telnetPromptNotFound(String)
    case connectionFailed(String)

    var errorDescription: String? {
        switch self {
        case .webViewNotAttached:
            return "WebView داخلی هنوز آماده نیست."
        case .timeout(let operation):
            return "زمان انتظار تمام شد: \(operation)"
        case .invalidURL(let value):
            return "آدرس نامعتبر است: \(value)"
        case .invalidJavaScriptResult:
            return "خروجی اسکریپت Huawei قابل خواندن نبود."
        case .scriptFailed(let message):
            return message
        case .telnetLoginFailed:
            return "ورود Telnet با رمزهای موجود انجام نشد."
        case .telnetPromptNotFound(let transcript):
            return "Prompt مورد انتظار در Telnet پیدا نشد. خروجی: \(transcript)"
        case .connectionFailed(let message):
            return message
        }
    }
}

enum JSONValue: Decodable, Equatable, CustomStringConvertible {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .object(try container.decode([String: JSONValue].self))
        }
    }

    var description: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .object(let value):
            return value.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
        case .array(let value):
            return value.map(\.description).joined(separator: ", ")
        case .null:
            return "null"
        }
    }
}

struct ScriptResult: Decodable, Equatable {
    struct NestedResult: Decodable, Equatable {
        let ok: Bool?
        let method: String?
        let userId: String?
        let passId: String?
        let buttonId: String?
        let formId: String?
        let functionName: String?
        let error: String?
        let diagnostics: [String]?
    }

    let ok: Bool?
    let logged: Bool?
    let error: String?
    let result: NestedResult?
    let found: [String: JSONValue]?
    let selected: [String: JSONValue]?
    let warnings: [String]?
    let apply: JSONValue?
    let url: String?
    let title: String?
    let hasPassword: Bool?
    let diagnostics: [String]?

    var succeeded: Bool {
        ok == true || logged == true || result?.ok == true
    }

    var compactSummary: String {
        if let error, !error.isEmpty {
            return error
        }
        if let nestedError = result?.error, !nestedError.isEmpty {
            return nestedError
        }
        var parts: [String] = []
        if let logged {
            parts.append("logged=\(logged)")
        }
        if let hasPassword {
            parts.append("passwordVisible=\(hasPassword)")
        }
        if let result {
            let ids = [
                result.method.map { "method=\($0)" },
                result.userId.map { "user=\($0)" },
                result.passId.map { "pass=\($0)" },
                result.buttonId.map { "button=\($0)" },
                result.formId.map { "form=\($0)" },
                result.functionName.map { "fn=\($0)" }
            ].compactMap { $0 }
            if !ids.isEmpty {
                parts.append(ids.joined(separator: ", "))
            }
            if let diagnostics = result.diagnostics, !diagnostics.isEmpty {
                parts.append("diag: " + diagnostics.prefix(6).joined(separator: " | "))
            }
        }
        if let found, !found.isEmpty {
            parts.append("found: " + found.keys.sorted().joined(separator: ", "))
        }
        if let selected, !selected.isEmpty {
            parts.append("selected: " + selected.keys.sorted().joined(separator: ", "))
        }
        if let warnings, !warnings.isEmpty {
            parts.append("warnings: " + warnings.joined(separator: " | "))
        }
        if let diagnostics, !diagnostics.isEmpty {
            parts.append("page: " + diagnostics.prefix(6).joined(separator: " | "))
        }
        if let url, !url.isEmpty {
            parts.append("url=\(url)")
        }
        if let title, !title.isEmpty {
            parts.append("title=\(title)")
        }
        return parts.isEmpty ? "ok" : parts.joined(separator: " | ")
    }
}
