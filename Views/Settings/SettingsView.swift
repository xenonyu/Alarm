import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.scenePhase) private var scenePhase
    @State private var alarmKitAuthorized = alarmKitIsAuthorized()

    private var currentCountryName: String {
        Locale.current.localizedString(forRegionCode: settings.holidayCountryCode)
            ?? settings.holidayCountryCode
    }

    var body: some View {
        @Bindable var settings = settings

        List {
            // ── Public Holidays ──────────────────────────────────────────────────
            Section {
                NavigationLink {
                    HolidayRegionPickerView()
                } label: {
                    HStack(spacing: 12) {
                        Text(settings.holidayCountryCode.flagEmoji)
                            .font(.title2)
                            .frame(width: 32)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Holiday Region")
                            Text(currentCountryName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } header: {
                Label("Public Holidays", systemImage: "calendar.badge.clock")
            } footer: {
                Text("Select a country to load its official public holidays.")
            }

            // ── Ringtone ──────────────────────────────────────────────────────────
            Section {
                ForEach(AlarmAudioService.ringtones, id: \.id) { tone in
                    Button {
                        settings.ringtone = tone.id
                        // Preview the selected ringtone
                        AlarmAudioService.shared.start(
                            title: "",
                            time: Date(),
                            ringtone: tone.id
                        )
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            AlarmAudioService.shared.stop()
                        }
                    } label: {
                        HStack {
                            Text(tone.displayName)
                                .foregroundStyle(.primary)
                            Spacer()
                            if settings.ringtone == tone.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            } header: {
                Label("Ringtone", systemImage: "music.note")
            } footer: {
                Text("Tap a ringtone to preview it.")
            }

            // ── Snooze ───────────────────────────────────────────────────────────
            Section {
                Picker("Duration", selection: $settings.snoozeMinutes) {
                    Text("5 min").tag(5)
                    Text("9 min").tag(9)
                    Text("10 min").tag(10)
                    Text("15 min").tag(15)
                }
                .pickerStyle(.segmented)
            } header: {
                Label("Snooze", systemImage: "alarm.waves.left.and.right")
            } footer: {
                Text("Snooze duration when you tap Snooze on an alarm notification.")
            }

            // ── Permissions ───────────────────────────────────────────────────────
            Section {
                if #available(iOS 26, *) {
                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                        HStack {
                            Label("Alarms", systemImage: "alarm")
                            if !alarmKitAuthorized {
                                Spacer()
                                Text("Not Allowed")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }
                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Label("Notifications", systemImage: "bell.badge")
                }
                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Label("Location", systemImage: "location")
                }
            } header: {
                Label("Permissions", systemImage: "lock.shield")
            } footer: {
                Text("Manage alarm, notification and location access in iOS Settings.")
            }

            // ── About ────────────────────────────────────────────────────────────
            Section {
                HStack {
                    Image(systemName: "alarm.fill")
                        .foregroundStyle(.tint)
                    Text("Alarm")
                    Spacer()
                    Text("1.0")
                        .foregroundStyle(.secondary)
                }
            } header: {
                Label("About", systemImage: "info.circle")
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { alarmKitAuthorized = alarmKitIsAuthorized() }
        }
    }
}

// MARK: - Flag Emoji Helper

extension String {
    /// Converts a 2-letter ISO country code to its flag emoji.
    var flagEmoji: String {
        unicodeScalars
            .compactMap { Unicode.Scalar(127397 + $0.value) }
            .map { String($0) }
            .joined()
    }
}
