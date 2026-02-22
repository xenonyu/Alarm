import SwiftUI
import WidgetKit

struct AlarmWidgetEntryView: View {
    let entry: AlarmWidgetEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall:   SmallAlarmView(entry: entry)
        case .systemMedium:  MediumAlarmView(entry: entry)
        case .accessoryCircular:    AccessoryCircularView(entry: entry)
        case .accessoryRectangular: AccessoryRectangularView(entry: entry)
        default: SmallAlarmView(entry: entry)
        }
    }
}

// MARK: - systemSmall

private struct SmallAlarmView: View {
    let entry: AlarmWidgetEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: "alarm.fill")
                .foregroundStyle(.tint)
                .font(.caption)
            if let time = entry.snapshot.nextAlarmTime {
                Text(time, style: .time)
                    .font(.system(size: 28, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.7)
                Text(time, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            } else {
                Text("No Alarm")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding()
    }
}

// MARK: - systemMedium

private struct MediumAlarmView: View {
    let entry: AlarmWidgetEntry

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "alarm.fill")
                .font(.largeTitle)
                .foregroundStyle(.tint)
                .frame(width: 44)

            if let time = entry.snapshot.nextAlarmTime {
                VStack(alignment: .leading, spacing: 2) {
                    if !entry.snapshot.nextAlarmTitle.isEmpty {
                        Text(entry.snapshot.nextAlarmTitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(time, style: .time)
                        .font(.system(size: 34, weight: .light, design: .rounded))
                        .monospacedDigit()
                    HStack(spacing: 4) {
                        Text("in")
                        Text(time, style: .relative)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if !entry.snapshot.nextAlarmRepeatLabel.isEmpty {
                        Text(entry.snapshot.nextAlarmRepeatLabel)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                Text("No upcoming alarm")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - accessoryCircular (lock screen)

private struct AccessoryCircularView: View {
    let entry: AlarmWidgetEntry

    var body: some View {
        if let time = entry.snapshot.nextAlarmTime {
            VStack(spacing: 0) {
                Image(systemName: "alarm.fill")
                    .font(.caption2)
                Text(time, style: .time)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
            }
        } else {
            Image(systemName: "alarm")
                .font(.title3)
        }
    }
}

// MARK: - accessoryRectangular (lock screen)

private struct AccessoryRectangularView: View {
    let entry: AlarmWidgetEntry

    var body: some View {
        if let time = entry.snapshot.nextAlarmTime {
            HStack(spacing: 6) {
                Image(systemName: "alarm.fill")
                    .font(.caption)
                VStack(alignment: .leading, spacing: 0) {
                    Text(time, style: .time)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .monospacedDigit()
                    Text(time, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Label("No Alarm", systemImage: "alarm")
                .font(.caption)
        }
    }
}
