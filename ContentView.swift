import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(AlarmStore.self) private var store
    @Environment(AlarmAudioService.self) private var audio
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Alarm.createdAt) private var alarms: [Alarm]

    @State private var selectedDateComps: DateComponents = {
        Calendar.current.dateComponents([.year, .month, .day], from: Date())
    }()

    var selectedDate: Date {
        Calendar.current.date(from: selectedDateComps) ?? Date()
    }

    var alarmsForSelected: [Alarm] {
        store.alarms(for: selectedDate, in: alarms)
    }

    var body: some View {
        Group {
            if #available(iOS 18, *) {
                tabRootView
            } else {
                legacyRootView
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { audio.isFiring },
            set: { if !$0 { audio.stop() } }
        )) {
            AlarmFiringView()
                .environment(audio)
                .environment(AppSettings.shared)
        }
    }

    // MARK: - iOS 18+ Tab View (glass floating tab bar on iOS 26)

    @available(iOS 18, *)
    private var tabRootView: some View {
        TabView {
            Tab("Alarms", systemImage: "alarm.fill") {
                allAlarmsNavigationStack
            }
            .badge(alarms.filter(\.isEnabled).count > 0 ? alarms.filter(\.isEnabled).count : 0)

            Tab("Calendar", systemImage: "calendar") {
                calendarNavigationStack
            }

            Tab("Settings", systemImage: "gearshape.fill") {
                NavigationStack {
                    SettingsView()
                }
            }
        }
        .onAppear { store.setup(modelContext: modelContext) }
    }

    // MARK: - All alarms navigation stack (home tab)

    private var allAlarmsNavigationStack: some View {
        NavigationStack {
            Group {
                if #available(iOS 26, *) {
                    GlassEffectContainer {
                        AllAlarmsView(alarms: alarms)
                    }
                } else {
                    AllAlarmsView(alarms: alarms)
                }
            }
            .navigationTitle("Alarms")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    // MARK: - Calendar navigation stack

    private var calendarNavigationStack: some View {
        NavigationStack {
            Group {
                if #available(iOS 26, *) {
                    GlassEffectContainer {
                        alarmContent
                    }
                } else {
                    alarmContent
                }
            }
            .navigationTitle("Calendar")
            .navigationBarTitleDisplayMode(.large)
        }
    }

    private var alarmContent: some View {
        AlarmListView(
            selectedDateComps: $selectedDateComps,
            allAlarms: alarms,
            date: selectedDate,
            alarms: alarmsForSelected
        )
    }

    // MARK: - iOS 17 fallback

    private var legacyRootView: some View {
        NavigationStack {
            alarmContent
                .navigationTitle("Alarms")
                .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { store.setup(modelContext: modelContext) }
    }
}
