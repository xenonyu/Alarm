import AlarmKit
import AppIntents
import Foundation
import SwiftUI

/// Wraps AlarmKit.AlarmManager for iOS 26+ alarm scheduling.
/// On iOS <26 this class is never instantiated; UNNotification + AlarmAudioService is used instead.
@available(iOS 26.0, *)
final class AlarmKitService {
    static let shared = AlarmKitService()
    private init() {}

    // MARK: - Authorization

    func requestAuthorization() async {
        try? await AlarmManager.shared.requestAuthorization()
    }

    /// Returns true when AlarmKit is available and the user has granted permission.
    /// Safe to call from any file without importing AlarmKit.
    static var isAuthorized: Bool {
        if #available(iOS 26, *) {
            return AlarmManager.shared.authorizationState == .authorized
        }
        return false
    }

    // MARK: - Schedule

    /// Cancels any existing AlarmKit alarms for this Alarm, then schedules new ones.
    func schedule(_ alarm: Alarm, holidays: Set<String>) async {
        await cancel(alarm)
        guard alarm.isEnabled else { return }

        let cal = Calendar.current
        let snoozeMinutes = AppSettings.shared.snoozeMinutes
        let hour = cal.component(.hour, from: alarm.time)
        let minute = cal.component(.minute, from: alarm.time)

        var kitIDs: [String] = []

        if !alarm.repeatWeekdays.isEmpty && !alarm.isLunar && !alarm.skipHolidays {
            // Weekly alarm without holiday-skipping → let the system manage recurrence
            let weekdays = alarm.repeatWeekdays.compactMap { Locale.Weekday(calendarWeekday: $0) }
            let alarmID = UUID()
            kitIDs.append(alarmID.uuidString)
            let kitSchedule = AlarmKit.Alarm.Schedule.relative(
                AlarmKit.Alarm.Schedule.Relative(
                    time: .init(hour: hour, minute: minute),
                    repeats: .weekly(weekdays)
                )
            )
            await scheduleOne(id: alarmID, alarm: alarm, kitSchedule: kitSchedule, snoozeMinutes: snoozeMinutes)
        } else {
            // One-time, lunar, or holiday-skipping → fixed alarms for each occurrence
            let dates = alarm.nextFireDates(count: 5, holidays: holidays)
            for date in dates {
                let alarmID = UUID()
                kitIDs.append(alarmID.uuidString)
                await scheduleOne(id: alarmID, alarm: alarm, kitSchedule: .fixed(date), snoozeMinutes: snoozeMinutes)
            }
        }

        UserDefaults.standard.set(kitIDs, forKey: udKey(for: alarm))
    }

    // MARK: - Cancel

    func cancel(_ alarm: Alarm) async {
        let kitIDs = UserDefaults.standard.stringArray(forKey: udKey(for: alarm)) ?? []
        for idStr in kitIDs {
            if let uuid = UUID(uuidString: idStr) {
                try? AlarmManager.shared.cancel(id: uuid)
            }
        }
        UserDefaults.standard.removeObject(forKey: udKey(for: alarm))
    }

    // MARK: - Private

    private func udKey(for alarm: Alarm) -> String {
        "AlarmKitIDs_\(alarm.id.uuidString)"
    }

    private func scheduleOne(
        id: UUID,
        alarm: Alarm,
        kitSchedule: AlarmKit.Alarm.Schedule,
        snoozeMinutes: Int
    ) async {
        let title = alarm.title.isEmpty ? String(localized: "Alarm") : alarm.title
        let titleResource: LocalizedStringResource = "\(title)"

        let stopIntent = StopAlarmIntent(alarmKitID: id.uuidString)
        let snoozeIntent = SnoozeAlarmIntent(
            alarmKitID: id.uuidString,
            alarmTitle: alarm.title,
            snoozeMinutes: snoozeMinutes
        )

        let snoozeButton = AlarmButton(
            text: LocalizedStringResource("Snooze"),
            textColor: .white,
            systemImageName: "alarm.waves.left.and.right"
        )

        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(
                title: titleResource,
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .custom
            )
        } else {
            let stopButton = AlarmButton(
                text: LocalizedStringResource("Stop"),
                textColor: .white,
                systemImageName: "xmark"
            )
            alert = AlarmPresentation.Alert(
                title: titleResource,
                stopButton: stopButton,
                secondaryButton: snoozeButton,
                secondaryButtonBehavior: .custom
            )
        }

        let metadata = AlarmKitMetadata(alarmTitle: alarm.title, snoozeMinutes: snoozeMinutes)
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: metadata,
            tintColor: .orange
        )
        let config = AlarmManager.AlarmConfiguration.alarm(
            schedule: kitSchedule,
            attributes: attributes,
            stopIntent: stopIntent,
            secondaryIntent: snoozeIntent
        )
        try? await AlarmManager.shared.schedule(id: id, configuration: config)
    }
}

// MARK: - Locale.Weekday helper

private extension Locale.Weekday {
    /// Converts a Calendar weekday component (1=Sun … 7=Sat) to Locale.Weekday.
    init?(calendarWeekday: Int) {
        switch calendarWeekday {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
}
