import SwiftUI

struct AlarmListView: View {
    @Binding var selectedDateComps: DateComponents
    let allAlarms: [Alarm]
    let date: Date
    let alarms: [Alarm]

    @Environment(AlarmStore.self) private var store
    @State private var showAdd = false
    @State private var editAlarm: Alarm? = nil

    var body: some View {
        List {
            // ── Calendar ─────────────────────────────────────────────────────
            Section {
                CalendarView(
                    selectedDate: $selectedDateComps,
                    alarms: allAlarms,
                    holidayService: store.holidayService,
                    holidayVersion: store.holidayService.holidayVersion
                )
                .padding(.horizontal, 4)
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // ── Date header ───────────────────────────────────────────────────
            Section {
                dateHeader
            }
            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            // ── Alarm rows ────────────────────────────────────────────────────
            if alarms.isEmpty {
                Section {
                    ContentUnavailableView(
                        "No Alarms",
                        systemImage: "alarm",
                        description: Text("Tap + to add an alarm for this day")
                    )
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                Section {
                    ForEach(alarms) { alarm in
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
                    }
                }
            }
        }
        .listStyle(.plain)
        .modifier(SoftScrollEdgeModifier())
        .sheet(isPresented: $showAdd) {
            AddAlarmView(initialDate: date)
        }
        .sheet(item: $editAlarm) { alarm in
            AddAlarmView(initialDate: date, existingAlarm: alarm)
        }
    }

    // MARK: - Date Header

    private var dateHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(date, format: .dateTime.month(.wide).day().weekday(.wide))
                    .font(.headline)

                if let name = store.holidayService.holidayName(for: date) {
                    Label(name, systemImage: "calendar.badge.minus")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            addButton
        }
        .padding(.vertical, 12)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            showAdd = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(Color.accentColor)
                .clipShape(Circle())
        }
        .accessibilityLabel("Add Alarm")
        .accessibilityIdentifier("addAlarmButton")
    }
}

// MARK: - Scroll Edge Modifier

private struct SoftScrollEdgeModifier: ViewModifier {
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
