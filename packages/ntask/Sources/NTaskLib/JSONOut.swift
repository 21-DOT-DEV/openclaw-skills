import Foundation

enum JSONOut {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static func success(_ fields: [String: Any]) {
        var dict = fields
        dict["ok"] = true
        printJSON(dict)
    }

    static func error(code: String, message: String, task: [String: Any]? = nil, exitCode: Int32) -> Never {
        var dict: [String: Any] = [
            "ok": false,
            "error": ["code": code, "message": message]
        ]
        if let task { dict["task"] = task }
        printJSON(dict)
        exit(exitCode)
    }

    static func printJSON(_ dict: [String: Any]) {
        if let data = try? JSONSerialization.data(
            withJSONObject: dict,
            options: [.prettyPrinted, .sortedKeys]
        ), let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }

    static func printEncodable<T: Encodable>(_ value: T) {
        if let data = try? encoder.encode(value),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }
}
