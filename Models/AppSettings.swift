import Foundation
import Observation

@Observable
final class AppSettings {
    static let shared = AppSettings()
    private let defaults = UserDefaults(suiteName: appGroupID) ?? .standard

    var snoozeMinutes: Int {
        didSet { defaults.set(snoozeMinutes, forKey: "snoozeMinutes") }
    }

    /// ISO 3166-1 alpha-2 country code for public holiday data (e.g. "CN", "US", "JP").
    /// Defaults to the device's current region; falls back to "CN" if unsupported.
    var holidayCountryCode: String {
        didSet { defaults.set(holidayCountryCode, forKey: "holidayCountryCode") }
    }

    /// Sound file name (without extension) for the alarm ringtone.
    var ringtone: String {
        didSet { defaults.set(ringtone, forKey: "ringtone") }
    }

    // MARK: - Peak Hours

    /// When true, adds extra buffer to commute alarms during Mon–Fri peak hours (7–9am, 5–7pm).
    var peakHoursAutoAdjust: Bool {
        didSet { defaults.set(peakHoursAutoAdjust, forKey: "peakHoursAutoAdjust") }
    }

    /// Extra minutes added to the commute buffer during peak hours.
    var peakHoursExtraMinutes: Int {
        didSet { defaults.set(peakHoursExtraMinutes, forKey: "peakHoursExtraMinutes") }
    }

    private init() {
        let saved = defaults.integer(forKey: "snoozeMinutes")
        self.snoozeMinutes = saved > 0 ? saved : 9

        if let code = defaults.string(forKey: "holidayCountryCode") {
            self.holidayCountryCode = code
        } else {
            let region = Locale.current.region?.identifier ?? "CN"
            let supported = HolidayService.supportedCountries.map(\.code)
            self.holidayCountryCode = supported.contains(region) ? region : "CN"
        }

        self.ringtone = defaults.string(forKey: "ringtone") ?? "alarm_classic"
        self.peakHoursAutoAdjust = defaults.bool(forKey: "peakHoursAutoAdjust")
        let savedPeak = defaults.integer(forKey: "peakHoursExtraMinutes")
        self.peakHoursExtraMinutes = savedPeak > 0 ? savedPeak : 15
    }
}
