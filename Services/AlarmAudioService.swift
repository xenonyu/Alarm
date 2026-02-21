import AVFoundation
import UserNotifications
import Observation

/// Manages alarm audio playback and the "alarm is firing" state.
/// When `isFiring` is true, ContentView presents AlarmFiringView.
@Observable
final class AlarmAudioService {

    static let shared = AlarmAudioService()
    private init() {}

    // MARK: - State

    private(set) var isFiring = false
    private(set) var firingTitle: String = ""
    private(set) var firingTime: Date = Date()

    private var player: AVAudioPlayer?

    // MARK: - Ringtone Catalogue

    struct Ringtone {
        let id: String
        let displayName: String
    }

    static let ringtones: [Ringtone] = [
        Ringtone(id: "alarm_classic", displayName: "Classic"),
        Ringtone(id: "alarm_digital", displayName: "Digital"),
        Ringtone(id: "alarm_gentle",  displayName: "Gentle"),
    ]

    // MARK: - Playback

    /// Start alarm: plays the chosen ringtone in a loop and raises `isFiring`.
    @MainActor
    func start(title: String, time: Date, ringtone: String) {
        firingTitle = title
        firingTime  = time

        let soundName = Self.ringtones.contains(where: { $0.id == ringtone }) ? ringtone : "alarm_classic"
        guard let url = Bundle.main.url(forResource: soundName, withExtension: "caf") else {
            isFiring = true   // still show UI even if audio fails
            return
        }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [])
            try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1   // loop forever
            player?.volume = 1.0
            player?.play()
        } catch {
            print("[AlarmAudioService] Audio error: \(error)")
        }
        isFiring = true
    }

    /// Stop alarm and deactivate audio session.
    @MainActor
    func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false,
              options: .notifyOthersOnDeactivation)
        isFiring = false
    }

    /// Stop and reschedule the alarm after the snooze duration.
    @MainActor
    func snooze(minutes: Int) {
        let title = firingTitle
        stop()

        let content = UNMutableNotificationContent()
        content.title              = title.isEmpty ? String(localized: "Alarm") : title
        content.body               = String(localized: "Snoozed")
        let ringtone               = AppSettings.shared.ringtone
        content.sound              = UNNotificationSound(named: UNNotificationSoundName(rawValue: "\(ringtone).caf"))
        content.categoryIdentifier = NotificationService.alarmCategoryID
        content.userInfo           = ["ringtone": ringtone, "fireTime": Date().addingTimeInterval(Double(minutes * 60)).timeIntervalSince1970]

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(minutes * 60), repeats: false)
        let request = UNNotificationRequest(identifier: "snooze-\(UUID().uuidString)", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }
}
