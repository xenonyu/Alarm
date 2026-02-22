import SwiftUI
import EventKit

struct CalendarIntegrationSettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AlarmStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    @State private var authStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    @State private var isRequesting = false

    private var isAuthorized: Bool { authStatus == .fullAccess }

    var body: some View {
        @Bindable var settings = settings

        List {
            // ── Enable toggle ───────────────────────────────────────────────────
            Section {
                Toggle(isOn: $settings.calendarSyncEnabled) {
                    Label("Sync Calendar Events", systemImage: "calendar")
                }
                .onChange(of: settings.calendarSyncEnabled) { _, enabled in
                    if enabled && !isAuthorized {
                        requestAccess()
                    } else if enabled {
                        store.syncCalendarAlarmsIfEnabled()
                    }
                }
            } footer: {
                Text("Automatically create alarms before upcoming calendar events.")
            }

            // ── Lead time ───────────────────────────────────────────────────────
            if settings.calendarSyncEnabled {
                Section {
                    Picker("Alarm Lead Time", selection: $settings.calendarLeadMinutes) {
                        Text("15 min").tag(15)
                        Text("30 min").tag(30)
                        Text("45 min").tag(45)
                        Text("60 min").tag(60)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.calendarLeadMinutes) { _, _ in
                        store.syncCalendarAlarmsIfEnabled()
                    }
                } header: {
                    Text("Lead Time")
                } footer: {
                    Text("How far in advance to ring the alarm before each event.")
                }
            }

            // ── Permission status ───────────────────────────────────────────────
            Section {
                HStack {
                    Label("Calendar Access", systemImage: "calendar.badge.checkmark")
                    Spacer()
                    switch authStatus {
                    case .fullAccess:
                        Text("Allowed")
                            .font(.caption)
                            .foregroundStyle(.green)
                    case .restricted, .denied, .writeOnly:
                        Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                            .font(.caption)
                    case .notDetermined:
                        if isRequesting {
                            ProgressView()
                        } else {
                            Button("Grant Access") { requestAccess() }
                                .font(.caption)
                        }
                    @unknown default:
                        EmptyView()
                    }
                }
            } header: {
                Text("Permissions")
            }
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                authStatus = EKEventStore.authorizationStatus(for: .event)
            }
        }
    }

    private func requestAccess() {
        isRequesting = true
        Task {
            let _ = await CalendarService.shared.requestAccess()
            await MainActor.run {
                authStatus = EKEventStore.authorizationStatus(for: .event)
                isRequesting = false
                if isAuthorized { store.syncCalendarAlarmsIfEnabled() }
            }
        }
    }
}
