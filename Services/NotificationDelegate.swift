import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    private override init() {}

    // Show banner + sound even when app is foregrounded
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Handle snooze action
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.actionIdentifier == NotificationService.snoozeActionID {
            let snoozeMin = AppSettings.shared.snoozeMinutes
            let fireDate = Date().addingTimeInterval(Double(snoozeMin * 60))

            let original = response.notification.request.content
            let content = UNMutableNotificationContent()
            content.title = original.title
            content.body = fireDate.timeString
            content.sound = .default
            content.categoryIdentifier = NotificationService.alarmCategoryID

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: Double(snoozeMin * 60),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: "snooze-\(UUID().uuidString)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
        completionHandler()
    }
}
