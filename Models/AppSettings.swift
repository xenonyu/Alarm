import Foundation
import Observation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var snoozeMinutes: Int {
        didSet { UserDefaults.standard.set(snoozeMinutes, forKey: "snoozeMinutes") }
    }

    /// ISO 3166-1 alpha-2 country code for public holiday data (e.g. "CN", "US", "JP").
    /// Defaults to the device's current region; falls back to "CN" if unsupported.
    var holidayCountryCode: String {
        didSet { UserDefaults.standard.set(holidayCountryCode, forKey: "holidayCountryCode") }
    }

    private init() {
        let saved = UserDefaults.standard.integer(forKey: "snoozeMinutes")
        self.snoozeMinutes = saved > 0 ? saved : 9

        if let code = UserDefaults.standard.string(forKey: "holidayCountryCode") {
            self.holidayCountryCode = code
        } else {
            let region = Locale.current.region?.identifier ?? "CN"
            let supported = HolidayService.supportedCountries.map(\.code)
            self.holidayCountryCode = supported.contains(region) ? region : "CN"
        }
    }
}
