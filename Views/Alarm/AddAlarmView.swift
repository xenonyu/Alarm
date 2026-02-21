import SwiftUI

struct AddAlarmView: View {
    let initialDate: Date
    let existingAlarm: Alarm?

    @Environment(\.dismiss) private var dismiss
    @Environment(AlarmStore.self) private var store

    // MARK: - Form state
    @State private var title: String
    @State private var time: Date
    @State private var targetDate: Date
    @State private var isRepeating: Bool
    @State private var repeatWeekdays: Set<Int>
    @State private var skipHolidays: Bool

    // MARK: - Lunar state
    @State private var isLunar: Bool
    @State private var lunarMonth: Int   // 1–12
    @State private var lunarDay: Int     // 1–30

    // MARK: - Commute state
    @State private var commuteEnabled: Bool
    @State private var commuteDestName: String
    @State private var commuteLatitude: Double
    @State private var commuteLongitude: Double
    @State private var commuteTransport: CommuteTransportType
    @State private var commuteBufferMinutes: Int
    @State private var estimatedTravelMin: Int
    @State private var isCalculatingRoute = false
    @State private var commuteErrorMessage: String?
    @State private var showDestinationPicker = false

    /// Weekday selector items ordered Mon→Sun.
    private var weekdayItems: [(Int, String)] {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return [2, 3, 4, 5, 6, 7, 1].map { wd in (wd, symbols[wd - 1]) }
    }

    // MARK: - Init

    init(initialDate: Date = Date(), existingAlarm: Alarm? = nil) {
        self.initialDate = initialDate
        self.existingAlarm = existingAlarm

        if let alarm = existingAlarm {
            _title              = State(wrappedValue: alarm.title)
            _time               = State(wrappedValue: alarm.time)
            _targetDate         = State(wrappedValue: alarm.targetDate ?? initialDate)
            _isRepeating        = State(wrappedValue: !alarm.repeatWeekdays.isEmpty)
            _repeatWeekdays     = State(wrappedValue: Set(alarm.repeatWeekdays))
            _skipHolidays       = State(wrappedValue: alarm.skipHolidays)
            _isLunar            = State(wrappedValue: alarm.isLunar)
            _lunarMonth         = State(wrappedValue: alarm.lunarMonth)
            _lunarDay           = State(wrappedValue: alarm.lunarDay)
            _commuteEnabled     = State(wrappedValue: alarm.commuteEnabled)
            _commuteDestName    = State(wrappedValue: alarm.commuteDestinationName)
            _commuteLatitude    = State(wrappedValue: alarm.commuteLatitude)
            _commuteLongitude   = State(wrappedValue: alarm.commuteLongitude)
            _commuteTransport   = State(wrappedValue: CommuteTransportType(rawValue: alarm.commuteTransportType) ?? .automobile)
            _commuteBufferMinutes = State(wrappedValue: alarm.commuteBufferMinutes)
            _estimatedTravelMin = State(wrappedValue: Int(alarm.commuteTravelSeconds / 60))
        } else {
            _title              = State(wrappedValue: "")
            _targetDate         = State(wrappedValue: initialDate)
            _isRepeating        = State(wrappedValue: false)
            _repeatWeekdays     = State(wrappedValue: [])
            _skipHolidays       = State(wrappedValue: false)
            _isLunar            = State(wrappedValue: false)
            _lunarMonth         = State(wrappedValue: 1)
            _lunarDay           = State(wrappedValue: 1)
            _commuteEnabled     = State(wrappedValue: false)
            _commuteDestName    = State(wrappedValue: "")
            _commuteLatitude    = State(wrappedValue: 0)
            _commuteLongitude   = State(wrappedValue: 0)
            _commuteTransport   = State(wrappedValue: .automobile)
            _commuteBufferMinutes = State(wrappedValue: 15)
            _estimatedTravelMin = State(wrappedValue: 0)
            // Default time: next upcoming hour
            let cal = Calendar.current
            var comps = cal.dateComponents([.year, .month, .day, .hour], from: Date())
            comps.minute = 0
            comps.second = 0
            let nextHour = cal.date(from: comps)
                .flatMap { cal.date(byAdding: .hour, value: 1, to: $0) } ?? Date()
            _time = State(wrappedValue: nextHour)
        }
    }

    var canSave: Bool {
        if !isLunar && isRepeating && repeatWeekdays.isEmpty { return false }
        if commuteEnabled && commuteLatitude == 0 { return false }
        return true
    }

    var body: some View {
        NavigationStack {
            Form {
                // Time picker
                Section {
                    if commuteEnabled {
                        Text("Arrival Time")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                // Label
                Section("Label") {
                    TextField("Name (optional)", text: $title)
                }

                // Repeat
                Section("Repeat") {
                    Toggle("Lunar Date (Annual)", isOn: $isLunar.animation())

                    if isLunar {
                        lunarPicker
                    } else {
                        Toggle("Repeat by Weekday", isOn: $isRepeating.animation())
                        if isRepeating {
                            weekdaySelector
                        } else {
                            DatePicker("Date", selection: $targetDate, displayedComponents: .date)
                        }
                    }
                }

                // Options
                Section("Options") {
                    Toggle(isOn: $skipHolidays) {
                        Label("Skip Public Holidays", systemImage: "calendar.badge.minus")
                    }
                }

                // Commute
                Section("Commute") {
                    Toggle(isOn: $commuteEnabled.animation()) {
                        Label("Enable Commute Reminder", systemImage: "car.circle")
                    }
                    .onChange(of: commuteEnabled) { _, enabled in
                        if enabled { LocationManager.shared.requestAuthorization() }
                    }

                    if commuteEnabled {
                        Button { showDestinationPicker = true } label: {
                            HStack {
                                Text("Destination").foregroundStyle(.primary)
                                Spacer()
                                Text(commuteDestName.isEmpty ? "Not Set" : commuteDestName)
                                    .foregroundStyle(commuteDestName.isEmpty ? .tertiary : .secondary)
                                    .lineLimit(1)
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .sheet(isPresented: $showDestinationPicker) {
                            DestinationPickerView(
                                name: $commuteDestName,
                                latitude: $commuteLatitude,
                                longitude: $commuteLongitude
                            )
                        }
                        .onChange(of: commuteLatitude) { _, _ in calculateRoute() }

                        Picker("Transport", selection: $commuteTransport) {
                            ForEach(CommuteTransportType.allCases) { type in
                                Label(type.label, systemImage: type.systemImage).tag(type)
                            }
                        }
                        .onChange(of: commuteTransport) { _, _ in calculateRoute() }

                        Stepper(value: $commuteBufferMinutes, in: 0...60, step: 5) {
                            HStack {
                                Text("Buffer")
                                Spacer()
                                Text("\(commuteBufferMinutes) min").foregroundStyle(.secondary)
                            }
                        }

                        HStack {
                            Text("Estimated Travel")
                            Spacer()
                            if isCalculatingRoute {
                                ProgressView()
                            } else if estimatedTravelMin > 0 {
                                Text("~\(estimatedTravelMin) min").foregroundStyle(.secondary)
                            } else {
                                Text("—").foregroundStyle(.tertiary)
                            }
                        }

                        if let msg = commuteErrorMessage {
                            Text(msg).font(.caption).foregroundStyle(.red)
                        }
                    }
                }
            }
            .navigationTitle(existingAlarm == nil ? "New Alarm" : "Edit Alarm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                if #available(iOS 26, *) {
                    ToolbarSpacer(.flexible)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .bold()
                        .disabled(!canSave)
                }
            }
        }
    }

    // MARK: - Lunar Picker

    private static let lunarMonthNames = [
        "正月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "冬月", "腊月"
    ]
    private static let lunarDayNames = [
        "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
    ]

    private var lunarPicker: some View {
        HStack {
            Picker("Month", selection: $lunarMonth) {
                ForEach(1...12, id: \.self) { m in
                    Text(Self.lunarMonthNames[m - 1]).tag(m)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()

            Picker("Day", selection: $lunarDay) {
                ForEach(1...30, id: \.self) { d in
                    Text(Self.lunarDayNames[d - 1]).tag(d)
                }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .clipped()
        }
        .frame(height: 120)
    }

    // MARK: - Weekday Selector

    private var weekdaySelector: some View {
        HStack(spacing: 0) {
            Spacer()
            ForEach(weekdayItems, id: \.0) { wd, label in
                Button {
                    if repeatWeekdays.contains(wd) {
                        repeatWeekdays.remove(wd)
                    } else {
                        repeatWeekdays.insert(wd)
                    }
                } label: {
                    Text(verbatim: label)
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 36, height: 36)
                        .modifier(WeekdayButtonStyle(selected: repeatWeekdays.contains(wd)))
                }
                .buttonStyle(.plain)
                if wd != weekdayItems.last?.0 { Spacer() }
            }
            Spacer()
        }
        .padding(.vertical, 6)
    }

    // MARK: - Route Calculation

    private func calculateRoute() {
        guard commuteEnabled && commuteLatitude != 0 else { return }
        commuteErrorMessage = nil
        isCalculatingRoute = true
        let lat = commuteLatitude
        let lon = commuteLongitude
        let transport = commuteTransport.mkType
        Task {
            defer { isCalculatingRoute = false }
            do {
                let seconds = try await CommuteService.shared.travelTime(
                    toLatitude: lat,
                    longitude: lon,
                    using: transport
                )
                estimatedTravelMin = Int(seconds / 60)
            } catch {
                commuteErrorMessage = error.localizedDescription
                estimatedTravelMin = 0
            }
        }
    }

    // MARK: - Save

    private func save() {
        if let existing = existingAlarm {
            // Edit existing alarm
            existing.title             = title
            existing.time              = time
            existing.isLunar           = isLunar
            existing.lunarMonth        = lunarMonth
            existing.lunarDay          = lunarDay
            existing.targetDate        = (isLunar || isRepeating) ? nil : targetDate
            existing.repeatWeekdays    = isLunar ? [] : Array(repeatWeekdays)
            existing.skipHolidays      = skipHolidays
            existing.commuteEnabled    = commuteEnabled
            if commuteEnabled && commuteLatitude != 0 {
                existing.commuteDestinationName = commuteDestName
                existing.commuteLatitude        = commuteLatitude
                existing.commuteLongitude       = commuteLongitude
                existing.commuteTransportType   = commuteTransport.rawValue
                existing.commuteBufferMinutes   = commuteBufferMinutes
                existing.commuteTravelSeconds   = Double(estimatedTravelMin * 60)
            } else {
                existing.commuteLatitude = 0
            }
            store.update(existing)
        } else {
            // Create new alarm
            let alarm = Alarm(
                title: title,
                time: time,
                targetDate: (isLunar || isRepeating) ? nil : targetDate,
                repeatWeekdays: isLunar ? [] : Array(repeatWeekdays),
                skipHolidays: skipHolidays
            )
            alarm.isLunar    = isLunar
            alarm.lunarMonth = lunarMonth
            alarm.lunarDay   = lunarDay
            if commuteEnabled && commuteLatitude != 0 {
                alarm.commuteEnabled         = true
                alarm.commuteDestinationName = commuteDestName
                alarm.commuteLatitude        = commuteLatitude
                alarm.commuteLongitude       = commuteLongitude
                alarm.commuteTransportType   = commuteTransport.rawValue
                alarm.commuteBufferMinutes   = commuteBufferMinutes
                alarm.commuteTravelSeconds   = Double(estimatedTravelMin * 60)
            }
            store.add(alarm)
        }
        dismiss()
    }
}

// MARK: - Weekday Button Style

private struct WeekdayButtonStyle: ViewModifier {
    let selected: Bool

    func body(content: Content) -> some View {
        if #available(iOS 26, *) {
            content
                .foregroundStyle(selected ? Color.accentColor : .primary)
                .glassEffect(Glass.regular.tint(selected ? Color.accentColor.opacity(0.4) : .clear), in: .circle)
        } else {
            content
                .background(Circle().fill(selected ? Color.accentColor : Color(.systemGray5)))
                .foregroundStyle(selected ? .white : .primary)
        }
    }
}
