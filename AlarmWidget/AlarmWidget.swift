import WidgetKit
import SwiftUI

@main
struct AlarmWidgetBundle: WidgetBundle {
    var body: some Widget {
        AlarmWidget()
    }
}

struct AlarmWidget: Widget {
    let kind = "AlarmWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: AlarmTimelineProvider()) { entry in
            AlarmWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Next Alarm")
        .description("Shows your next scheduled alarm.")
        .supportedFamilies([
            .systemSmall,
            .systemMedium,
            .accessoryCircular,
            .accessoryRectangular
        ])
    }
}
