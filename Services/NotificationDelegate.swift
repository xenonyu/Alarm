import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    private override init() {}

    // MARK: - Foreground delivery

    /// When an alarm notification fires while the app is open, show the in-app alarm UI.
    /// On iOS 26+ with AlarmKit authorized, UNNotifications are only used for commute
    /// reminders (no ringtone key), so this branch won't be reached for regular alarms.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let info = notification.request.content.userInfo
        if let ringtone = info["ringtone"] as? String {
            // Use in-app alarm when AlarmKit is not authorized (or not available)
            let useInApp: Bool
            if #available(iOS 26, *) { useInApp = !AlarmKitService.isAuthorized } else { useInApp = true }
            if useInApp {
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
            // Snooze: reschedule a new notification
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
            // Default tap: show in-app alarm UI when AlarmKit is not handling it
            let showInApp: Bool
            if #available(iOS 26, *) { showInApp = !AlarmKitService.isAuthorized } else { showInApp = true }
            if showInApp {
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
