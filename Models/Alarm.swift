import Foundation
import SwiftData

@Model
final class Alarm {
    var id: UUID
    var title: String
    var time: Date
    var targetDate: Date?
    /// Calendar weekday values: 1=Sunday, 2=Monday … 7=Saturday
    var repeatWeekdays: [Int]
    var skipHolidays: Bool
    var isEnabled: Bool
    var createdAt: Date

    // MARK: - Commute
    /// When commute mode is on, `time` represents the desired *arrival* time.
    /// The "leave now" notification fires at: time − commuteTravelSeconds − commuteBufferMinutes·60
    var commuteEnabled: Bool = false
    var commuteDestinationName: String = ""
    var commuteLatitude: Double = 0
    var commuteLongitude: Double = 0
    /// Raw value of `CommuteTransportType` (0=auto 1=walk 2=transit)
    var commuteTransportType: Int = 0
    /// Extra buffer added on top of travel time (default 15 min)
    var commuteBufferMinutes: Int = 15
    /// Last successfully fetched travel time in seconds (cached for notification scheduling)
    var commuteTravelSeconds: Double = 0

    init(
        title: String,
        time: Date,
        targetDate: Date? = nil,
        repeatWeekdays: [Int] = [],
        skipHolidays: Bool = false
    ) {
        self.id = UUID()
        self.title = title
        self.time = time
        self.targetDate = targetDate
        self.repeatWeekdays = repeatWeekdays
        self.skipHolidays = skipHolidays
        self.isEnabled = true
        self.createdAt = Date()
    }

    var isRepeating: Bool { !repeatWeekdays.isEmpty }

    // MARK: - Calendar Logic

    /// Whether this alarm fires on a given calendar date.
    func fires(on date: Date, holidays: Set<String>) -> Bool {
        guard isEnabled else { return false }
        let dateStr = DateFormatter.yyyyMMdd.string(from: date)
        if skipHolidays && holidays.contains(dateStr) { return false }

        if isRepeating {
            return repeatWeekdays.contains(Calendar.current.component(.weekday, from: date))
        } else if let target = targetDate {
            return Calendar.current.isDate(date, inSameDayAs: target)
        }
        return false
    }

    /// Returns the next `count` fire dates from `start`, skipping holidays where configured.
    func nextFireDates(from start: Date = Date(), count: Int = 20, holidays: Set<String>) -> [Date] {
        var results: [Date] = []
        let cal = Calendar.current
        var day = cal.startOfDay(for: start)

        for _ in 0..<730 {
            guard results.count < count else { break }

            let dateStr = DateFormatter.yyyyMMdd.string(from: day)
            let isHoliday = holidays.contains(dateStr)

            if !(skipHolidays && isHoliday) {
                let weekday = cal.component(.weekday, from: day)
                var shouldFire = false

                if isRepeating {
                    shouldFire = repeatWeekdays.contains(weekday)
                } else if let target = targetDate {
                    shouldFire = cal.isDate(day, inSameDayAs: target)
                }

                if shouldFire, let fireDate = combineDateAndTime(date: day, time: time) {
                    if fireDate > Date() {
                        results.append(fireDate)
                    }
                    if !isRepeating { break }
                }
            }

            day = cal.date(byAdding: .day, value: 1, to: day) ?? day
        }

        return results
    }

    private func combineDateAndTime(date: Date, time: Date) -> Date? {
        let cal = Calendar.current
        let t = cal.dateComponents([.hour, .minute], from: time)
        return cal.date(bySettingHour: t.hour ?? 0, minute: t.minute ?? 0, second: 0, of: date)
    }
}
