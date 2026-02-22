import SwiftUI
import SwiftData

@main
struct AlarmApp: App {
    @State private var store = AlarmStore()
    @State private var audio = AlarmAudioService.shared
    private let settings = AppSettings.shared

    private static let modelContainer: ModelContainer = {
        // CloudKit sync requires a paid Apple Developer account + iCloud entitlement.
        // Using local-only store for personal team builds.
        return try! ModelContainer(for: Alarm.self)
    }()

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
        .modelContainer(Self.modelContainer)
    }
}
