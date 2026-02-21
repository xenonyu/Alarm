import SwiftUI
import SwiftData

@main
struct AlarmApp: App {
    @State private var store = AlarmStore()
    private let settings = AppSettings.shared

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        NotificationService.registerCategories()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .environment(settings)
        }
        .modelContainer(for: Alarm.self)
    }
}
