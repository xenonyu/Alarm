import SwiftUI

struct AllAlarmsView: View {
    let alarms: [Alarm]

    @Environment(AlarmStore.self) private var store
    @State private var showAdd = false
    @State private var editAlarm: Alarm? = nil

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

    /// Earliest next fire date among all enabled alarms.
    private var nextAlarmDate: Date? {
        alarms
            .filter(\.isEnabled)
            .compactMap { $0.nextFireDates(from: Date(), count: 1, holidays: store.holidayService.allHolidays).first }
            .min()
    }

    var body: some View {
        List {
            // ── Next alarm countdown ──────────────────────────────────────────────
            if let next = nextAlarmDate {
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
                        AlarmRowView(alarm: alarm)
                            .contentShape(Rectangle())
                            .onTapGesture { editAlarm = alarm }
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
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                addButton
            }
        }
        .sheet(isPresented: $showAdd) {
            AddAlarmView()
        }
        .sheet(item: $editAlarm) { alarm in
            AddAlarmView(existingAlarm: alarm)
        }
    }

    // MARK: - Add Button

    @ViewBuilder
    private var addButton: some View {
        if #available(iOS 26, *) {
            Button { showAdd = true } label: {
                Image(systemName: "plus")
                    .font(.title3.bold())
                    .padding(9)
            }
            .glassEffect(in: .circle)
            .accessibilityLabel("Add Alarm")
        } else {
            Button { showAdd = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
            }
            .accessibilityLabel("Add Alarm")
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
