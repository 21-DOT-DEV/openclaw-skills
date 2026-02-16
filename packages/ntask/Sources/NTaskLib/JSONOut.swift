import Foundation

enum JSONOut {
    static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    static func error(code: String, message: String, task: TaskSummary? = nil, exitCode: Int32) -> Never {
        let response = NTaskErrorResponse(
            error: NTaskErrorPayload(code: code, message: message),
            task: task
        )
        printEncodable(response)
        exit(exitCode)
    }

    static func printEncodable<T: Encodable>(_ value: T) {
        if let data = try? encoder.encode(value),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    }
}
