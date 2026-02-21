import Foundation
import Observation

@Observable
final class AppSettings {
    static let shared = AppSettings()

    var snoozeMinutes: Int {
        didSet { UserDefaults.standard.set(snoozeMinutes, forKey: "snoozeMinutes") }
    }

    private init() {
        let saved = UserDefaults.standard.integer(forKey: "snoozeMinutes")
        self.snoozeMinutes = saved > 0 ? saved : 9
    }
}
