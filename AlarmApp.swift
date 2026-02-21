import SwiftUI
import SwiftData

@main
struct AlarmApp: App {
    @State private var store = AlarmStore()
    @State private var audio = AlarmAudioService.shared
    private let settings = AppSettings.shared

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        NotificationService.registerCategories()
        if #available(iOS 26, *) {
            Task { await AlarmKitService.shared.requestAuthorization() }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(audio)
                .environment(settings)
        }
        .modelContainer(for: Alarm.self)
    }
}
