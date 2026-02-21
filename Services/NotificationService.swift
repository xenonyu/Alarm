import Foundation
import UserNotifications

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    // MARK: - Category / Action IDs

    static let alarmCategoryID = "ALARM_CATEGORY"
    static let snoozeActionID  = "SNOOZE"

    /// Call once at app launch to register the notification category with Snooze action.
    static func registerCategories() {
        let snooze = UNNotificationAction(
            identifier: snoozeActionID,
            title: String(localized: "Snooze"),
            options: []
        )
        let category = UNNotificationCategory(
            identifier: alarmCategoryID,
            actions: [snooze],
            intentIdentifiers: [],
            options: []
        )
        UNUserNotificationCenter.current().setNotificationCategories([category])
    }

    // MARK: - Permission

    @discardableResult
    func requestPermission() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - Schedule

    /// Cancels existing notifications for the alarm and schedules the next occurrences.
    func schedule(_ alarm: Alarm, holidays: Set<String>) async {
        await cancel(alarm)
        guard alarm.isEnabled else { return }

        if alarm.commuteEnabled && alarm.commuteTravelSeconds > 0 {
            // Commute alarms always use UNNotification (departure reminder, not a full alarm)
            let dates = alarm.nextFireDates(count: 20, holidays: holidays)
            for date in dates {
                await scheduleCommuteNotification(alarm: alarm, arrivalDate: date)
            }
        } else if #available(iOS 26, *) {
            // Regular alarms on iOS 26+: system-managed via AlarmKit
            await AlarmKitService.shared.schedule(alarm, holidays: holidays)
        } else {
            // Regular alarms on iOS <26: UNNotification + in-app AlarmAudioService
            let dates = alarm.nextFireDates(count: 20, holidays: holidays)
            for date in dates {
                await scheduleRegularNotification(alarm: alarm, at: date)
            }
        }
    }

    /// Removes all pending notifications and AlarmKit alarms for this alarm.
    func cancel(_ alarm: Alarm) async {
        // Cancel UNNotifications (commute alarms, and regular alarms on iOS <26)
        let center = UNUserNotificationCenter.current()
        let pending = await center.pendingNotificationRequests()
        let ids = pending
            .filter { $0.identifier.hasPrefix(alarm.id.uuidString) }
            .map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: ids)

        // Cancel AlarmKit alarms (iOS 26+)
        if #available(iOS 26, *) {
            await AlarmKitService.shared.cancel(alarm)
        }
    }

    // MARK: - Private

    /// Fires a "leave now" notification before the desired arrival time.
    private func scheduleCommuteNotification(alarm: Alarm, arrivalDate: Date) async {
        let departureDate = arrivalDate.addingTimeInterval(
            -(alarm.commuteTravelSeconds + Double(alarm.commuteBufferMinutes) * 60)
        )
        guard departureDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time to Leave!")
        let travelMin = Int(alarm.commuteTravelSeconds / 60)
        let dest = alarm.commuteDestinationName.isEmpty ? "" : " → \(alarm.commuteDestinationName)"
        content.body = "\(arrivalDate.timeString)\(dest) · ~\(travelMin) min"
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: departureDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = "\(alarm.id.uuidString)-commute-\(Int(arrivalDate.timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }

    private func scheduleRegularNotification(alarm: Alarm, at date: Date) async {
        let ringtone = AppSettings.shared.ringtone
        let content = UNMutableNotificationContent()
        content.title = alarm.title.isEmpty ? String(localized: "Alarm") : alarm.title
        content.body = date.timeString
        content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(ringtone).caf"))
        content.categoryIdentifier = NotificationService.alarmCategoryID
        content.userInfo = [
            "ringtone": ringtone,
            "fireTime": date.timeIntervalSince1970
        ]

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: date
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = "\(alarm.id.uuidString)-\(Int(date.timeIntervalSince1970))"
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
