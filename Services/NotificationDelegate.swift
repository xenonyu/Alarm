import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    private override init() {}

    // MARK: - Foreground delivery

    /// When alarm fires while app is open: start in-app alarm immediately.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let info = notification.request.content.userInfo
        if let ringtone = info["ringtone"] as? String {
            // Alarm notification (iOS <26 only): show banner, start looping in-app audio.
            // On iOS 26+ AlarmKit manages the alarm UI; UNNotification is only used for commute reminders.
            if #unavailable(iOS 26) {
                let fireTime = (info["fireTime"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
                let title    = notification.request.content.title
                Task { @MainActor in
                    AlarmAudioService.shared.start(title: title, time: fireTime, ringtone: ringtone)
                }
            }
            completionHandler([.banner])
        } else {
            completionHandler([.banner, .sound])
        }
    }

    // MARK: - User interaction

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let info     = response.notification.request.content.userInfo
        let ringtone = info["ringtone"] as? String ?? AppSettings.shared.ringtone

        if response.actionIdentifier == NotificationService.snoozeActionID {
            // Snooze: reschedule a new notification, no alarm UI
            let snoozeMin = AppSettings.shared.snoozeMinutes
            let fireDate  = Date().addingTimeInterval(Double(snoozeMin * 60))

            let content = UNMutableNotificationContent()
            content.title              = response.notification.request.content.title
            content.body               = String(localized: "Snoozed")
            content.sound              = UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(ringtone).caf"))
            content.categoryIdentifier = NotificationService.alarmCategoryID
            content.userInfo           = ["ringtone": ringtone, "fireTime": fireDate.timeIntervalSince1970]

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(snoozeMin * 60), repeats: false)
            center.add(UNNotificationRequest(identifier: "snooze-\(UUID().uuidString)", content: content, trigger: trigger))

        } else if info["ringtone"] != nil {
            // Default tap on an alarm notification (iOS <26 only): show in-app alarm UI.
            if #unavailable(iOS 26) {
                let fireTime = (info["fireTime"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? Date()
                let title    = response.notification.request.content.title
                Task { @MainActor in
                    AlarmAudioService.shared.start(title: title, time: fireTime, ringtone: ringtone)
                }
            }
        }
        completionHandler()
    }
}
