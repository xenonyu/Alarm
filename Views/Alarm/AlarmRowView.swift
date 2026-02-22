import SwiftUI

struct AlarmRowView: View {
    let alarm: Alarm
    var onTap: (() -> Void)? = nil
    @Environment(AlarmStore.self) private var store

    private static let lunarMonthNames = [
        "正月", "二月", "三月", "四月", "五月", "六月",
        "七月", "八月", "九月", "十月", "冬月", "腊月"
    ]
    private static let lunarDayNames = [
        "初一", "初二", "初三", "初四", "初五", "初六", "初七", "初八", "初九", "初十",
        "十一", "十二", "十三", "十四", "十五", "十六", "十七", "十八", "十九", "二十",
        "廿一", "廿二", "廿三", "廿四", "廿五", "廿六", "廿七", "廿八", "廿九", "三十"
    ]

    /// Human-readable repeat summary, fully locale-aware via system Calendar symbols.
    var repeatLabel: String {
        if alarm.isLunar {
            let m = (1...12).contains(alarm.lunarMonth) ? Self.lunarMonthNames[alarm.lunarMonth - 1] : "\(alarm.lunarMonth)月"
            let d = (1...30).contains(alarm.lunarDay)   ? Self.lunarDayNames[alarm.lunarDay - 1]     : "\(alarm.lunarDay)日"
            return "农历 \(m)\(d)"
        }
        guard alarm.isRepeating else {
            if let date = alarm.targetDate {
                return date.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated))
            }
            return String(localized: "Once")
        }
        let sorted = alarm.repeatWeekdays.sorted()
        if sorted.count == 7 { return String(localized: "Every Day") }
        if sorted == [2, 3, 4, 5, 6] { return String(localized: "Weekdays") }
        if sorted == [1, 7] { return String(localized: "Weekends") }
        let symbols = Calendar.current.shortStandaloneWeekdaySymbols
        return sorted
            .compactMap { wd in (1...7).contains(wd) ? symbols[wd - 1] : nil }
            .joined(separator: " ")
    }

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // MARK: Left — time + metadata (tap to edit)
            Button { onTap?() } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text(alarm.time, style: .time)
                        .font(.system(size: 48, weight: .ultraLight, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(alarm.isEnabled ? .primary : .secondary)
                        .modifier(AlarmWiggleEffect(isEnabled: alarm.isEnabled))

                    // Subtitle: title · repeat · holiday
                    subtitleRow
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // MARK: Right — toggle (independent, does not trigger edit)
            Toggle(
                "",
                isOn: Binding(
                    get: { alarm.isEnabled },
                    set: { _ in store.toggle(alarm) }
                )
            )
            .labelsHidden()
            .padding(.leading, 8)
        }
        .padding(.vertical, 14)
        .opacity(alarm.isEnabled ? 1 : 0.5)
    }

    // MARK: - Subtitle

    @ViewBuilder
    private var subtitleRow: some View {
        let showHolidayBadge = alarm.skipHolidays && !alarm.commuteEnabled
        let hasSubtitle = !alarm.title.isEmpty || showHolidayBadge || alarm.commuteEnabled

        if hasSubtitle {
            VStack(alignment: .leading, spacing: 3) {
                // Main subtitle: title · repeatLabel  [holiday icon]
                HStack(spacing: 4) {
                    if !alarm.title.isEmpty {
                        Text(alarm.title)
                        Text("·").foregroundStyle(.tertiary)
                    }
                    Text(repeatLabel)
                    if alarm.calendarEventID != nil {
                        Image(systemName: "calendar")
                            .foregroundStyle(.blue)
                    }
                    if showHolidayBadge {
                        Image(systemName: "calendar.badge.minus")
                            .foregroundStyle(.orange)
                    }
                }
                .font(.subheadline)
                .fontDesign(.rounded)
                .foregroundStyle(alarm.isEnabled ? .secondary : .tertiary)

                if alarm.commuteEnabled && !alarm.commuteDestinationName.isEmpty {
                    commuteRow
                }
            }
        }
    }

    private var commuteRow: some View {
        let travelMin = Int(alarm.commuteTravelSeconds / 60)
        let icon = CommuteTransportType(rawValue: alarm.commuteTransportType)?.systemImage ?? "car.fill"
        return HStack(spacing: 4) {
            Image(systemName: icon)
            Text(alarm.commuteDestinationName).lineLimit(1)
            if travelMin > 0 {
                Text("·").foregroundStyle(.tertiary)
                Text("~\(travelMin) min").foregroundStyle(.tertiary)
            }
            if alarm.skipHolidays {
                Image(systemName: "calendar.badge.minus").foregroundStyle(.orange)
            }
        }
        .font(.caption)
        .fontDesign(.rounded)
        .foregroundStyle(.tint)
    }
}

// MARK: - Wiggle Effect (iOS 18+)

private struct AlarmWiggleEffect: ViewModifier {
    let isEnabled: Bool

    func body(content: Content) -> some View {
        if #available(iOS 18, *) {
            content.symbolEffect(.wiggle, value: isEnabled)
        } else {
            content
        }
    }
}
