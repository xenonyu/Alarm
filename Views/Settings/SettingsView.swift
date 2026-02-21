import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

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
                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Label("Notifications", systemImage: "bell.badge")
                }
                Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                    Label("Location", systemImage: "location")
                }
            } header: {
                Label("Permissions", systemImage: "lock.shield")
            } footer: {
                Text("Manage notification and location access in iOS Settings.")
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
