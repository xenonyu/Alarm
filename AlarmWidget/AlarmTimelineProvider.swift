import WidgetKit

struct AlarmWidgetEntry: TimelineEntry {
    let date: Date
    let snapshot: AlarmWidgetSnapshot
}

struct AlarmTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> AlarmWidgetEntry {
        AlarmWidgetEntry(date: .now, snapshot: .empty)
    }

    func getSnapshot(in context: Context, completion: @escaping (AlarmWidgetEntry) -> Void) {
        completion(AlarmWidgetEntry(date: .now, snapshot: AlarmWidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<AlarmWidgetEntry>) -> Void) {
        let snapshot = AlarmWidgetSnapshot.load()
        let entry = AlarmWidgetEntry(date: .now, snapshot: snapshot)

        // Refresh at the alarm fire time, or in 15 minutes if no alarm is set
        let nextRefresh: Date
        if let alarmTime = snapshot.nextAlarmTime, alarmTime > .now {
            nextRefresh = alarmTime.addingTimeInterval(60)
        } else {
            nextRefresh = Date().addingTimeInterval(900)
        }

        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }
}
