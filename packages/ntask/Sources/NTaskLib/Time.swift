import Foundation

enum Time {
    nonisolated(unsafe) private static let _formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func now() -> Date { Date() }

    static func iso8601(_ date: Date) -> String {
        _formatter.string(from: date)
    }

    static func leaseExpiry(from date: Date = Date(), minutes: Int) -> Date {
        date.addingTimeInterval(TimeInterval(minutes * 60))
    }

    static func parse(_ string: String) -> Date? {
        _formatter.date(from: string)
    }

    static func isExpired(_ dateString: String) -> Bool {
        guard let date = parse(dateString) else { return true }
        return date < now()
    }
}
