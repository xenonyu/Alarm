import SwiftUI
import SwiftData

@main
struct AlarmApp: App {
    @State private var store = AlarmStore()
    @State private var audio = AlarmAudioService.shared
    private let settings = AppSettings.shared

    private static let modelContainer: ModelContainer = {
        let config = ModelConfiguration(
            cloudKitDatabase: .private("iCloud.com.yumingxie.Alarm")
        )
        return try! ModelContainer(for: Alarm.self, configurations: config)
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
