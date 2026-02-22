import Foundation

/// Snapshot of the next alarm, written by the main app and read by the Widget extension.
/// Stored in the shared App Group UserDefaults so the widget can access it without the app running.
struct AlarmWidgetSnapshot: Codable {
    var nextAlarmTime: Date?
    var nextAlarmTitle: String
    var nextAlarmRepeatLabel: String

    static let empty = AlarmWidgetSnapshot(nextAlarmTime: nil, nextAlarmTitle: "", nextAlarmRepeatLabel: "")

    // MARK: - Persistence

    private static let key = "AlarmWidgetSnapshot"
    private static var defaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

    static func load() -> AlarmWidgetSnapshot {
        guard
            let data = defaults.data(forKey: key),
            let snap = try? JSONDecoder().decode(AlarmWidgetSnapshot.self, from: data)
        else { return .empty }
        return snap
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            Self.defaults.set(data, forKey: Self.key)
        }
    }
}
