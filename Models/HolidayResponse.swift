import Foundation

struct HolidayResponse: Codable {
    let code: Int
    let holiday: [String: HolidayEntry]
}

struct HolidayEntry: Codable {
    /// true = public holiday (day off); false = makeup workday (weekend → workday)
    let holiday: Bool
    let name: String
    let wage: Int
    let date: String
    let after: Bool?
    let target: String?
}
