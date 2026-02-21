import Foundation

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    static let hmm: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
}

extension Date {
    var yyyyMMdd: String { DateFormatter.yyyyMMdd.string(from: self) }
    var timeString: String { DateFormatter.hmm.string(from: self) }
}
