import SwiftUI

struct AllAlarmsView: View {
    let alarms: [Alarm]

    @Environment(AlarmStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var showAdd = false
    @State private var editAlarm: Alarm? = nil
    @State private var alarmKitAuthorized = alarmKitIsAuthorized()

    /// Sort enabled alarms first, then by time-of-day.
    private var sortedAlarms: [Alarm] {
        alarms.sorted { a, b in
            if a.isEnabled != b.isEnabled { return a.isEnabled }
            let cal = Calendar.current
            let ac = cal.dateComponents([.hour, .minute], from: a.time)
            let bc = cal.dateComponents([.hour, .minute], from: b.time)
            let am = (ac.hour ?? 0) * 60 + (ac.minute ?? 0)
            let bm = (bc.hour ?? 0) * 60 + (bc.minute ?? 0)
            return am < bm
        }
    }

    /// Earliest next fire date among all enabled alarms that is still in the future.
    private func nextAlarmDate(after now: Date) -> Date? {
        alarms
            .filter(\.isEnabled)
            .compactMap { $0.nextFireDates(from: now, count: 1, holidays: store.holidayService.allHolidays).first }
            .filter { $0 > now }
            .min()
    }

    var body: some View {
        List {
            // ── AlarmKit authorization warning ───────────────────────────────────
            if #available(iOS 26, *), !alarmKitAuthorized {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 10) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                            Text("Alarm Permission Required")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                                Text("Open Settings")
                                    .font(.caption.weight(.semibold))
                            }
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("To allow alarms to ring:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("1. Tap **Open Settings** above")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("2. Scroll down and tap **Alarm**")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("3. Enable the **Alarms** toggle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.orange.opacity(0.10))
                .listRowSeparator(.hidden)
            }

            // ── Next alarm countdown ──────────────────────────────────────────────
            // Outer guard reacts immediately to toggle changes (SwiftData array).
            // Inner TimelineView drops past dates by re-evaluating every minute.
            if alarms.contains(where: \.isEnabled) {
            TimelineView(.everyMinute) { context in
                if let next = nextAlarmDate(after: context.date) {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "alarm.fill")
                                .font(.title2)
                                .foregroundStyle(.tint)
                                .frame(width: 32)

                            VStack(alignment: .leading, spacing: 1) {
                                Text("Next Alarm")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(next, style: .time)
                                    .font(.system(size: 22, weight: .light, design: .rounded))
                                    .monospacedDigit()
                                    .foregroundStyle(.tint)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 1) {
                                Text("in")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(next, style: .relative)
                                    .font(.subheadline.weight(.medium))
                                    .fontDesign(.rounded)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.accentColor.opacity(0.08))
                    .listRowSeparator(.hidden)
                }
            }
            } // end if alarms.contains(where: \.isEnabled)

            if alarms.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Alarms",
                        systemImage: "alarm",
                        description: Text("Tap + to add your first alarm")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(sortedAlarms) { alarm in
                        AlarmRowView(alarm: alarm, onTap: { editAlarm = alarm })
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    store.delete(alarm)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .listStyle(.plain)
        .modifier(AllAlarmsSoftScrollEdge())
        .overlay(alignment: .bottomTrailing) {
            Button {
                showAdd = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 24)
            .padding(.bottom, 24)
            .accessibilityLabel("Add Alarm")
            .accessibilityIdentifier("addAlarmButton")
        }
        .sheet(isPresented: $showAdd) {
            AddAlarmView()
        }
        .sheet(item: $editAlarm) { alarm in
            AddAlarmView(existingAlarm: alarm)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { alarmKitAuthorized = alarmKitIsAuthorized() }
        }
    }
}

// MARK: - Scroll Edge Modifier

private struct AllAlarmsSoftScrollEdge: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .scrollEdgeEffectStyle(.soft, for: .top)
                .scrollEdgeEffectStyle(.soft, for: .bottom)
        } else {
            content
        }
    }
}
