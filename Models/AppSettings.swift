import Foundation
import Observation

/// Shared App Group identifier used by the main app, Widget, and Watch extensions.
let appGroupID = "group.com.yumingxie.Alarm"

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
    }
}
