import AppIntents
import AlarmKit
import SwiftUI

// MARK: - AlarmKit Metadata

@available(iOS 26.0, *)
struct AlarmKitMetadata: AlarmMetadata {
    var alarmTitle: String
    var snoozeMinutes: Int
}

// MARK: - Stop Intent

/// Called by the system when the user taps "Stop" on the AlarmKit alarm screen.
@available(iOS 26.0, *)
struct StopAlarmIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Stop Alarm"

    @Parameter(title: "Alarm Kit ID")
    var alarmKitID: String

    init() {}

    init(alarmKitID: String) {
        self.alarmKitID = alarmKitID
    }

    func perform() async throws -> some IntentResult {
        if let uuid = UUID(uuidString: alarmKitID) {
            try? AlarmManager.shared.stop(id: uuid)
        }
        return .result()
    }
}

// MARK: - Snooze Intent

/// Called by the system when the user taps "Snooze" on the AlarmKit alarm screen.
/// Stops the current alarm and schedules a new one-time alarm after the snooze duration.
@available(iOS 26.0, *)
struct SnoozeAlarmIntent: AppIntent, LiveActivityIntent {
    static let title: LocalizedStringResource = "Snooze Alarm"

    @Parameter(title: "Alarm Kit ID")
    var alarmKitID: String

    @Parameter(title: "Alarm Title")
    var alarmTitle: String

    @Parameter(title: "Snooze Minutes")
    var snoozeMinutes: Int

    init() {}

    init(alarmKitID: String, alarmTitle: String, snoozeMinutes: Int) {
        self.alarmKitID = alarmKitID
        self.alarmTitle = alarmTitle
        self.snoozeMinutes = snoozeMinutes
    }

    func perform() async throws -> some IntentResult {
        // Stop the currently alerting alarm
        if let uuid = UUID(uuidString: alarmKitID) {
            try? AlarmManager.shared.stop(id: uuid)
        }

        // Schedule a new one-time alarm after the snooze duration
        let snoozeID = UUID()
        let fireDate = Date().addingTimeInterval(Double(snoozeMinutes) * 60)
        let displayTitle = alarmTitle.isEmpty ? String(localized: "Alarm") : alarmTitle
        let titleResource: LocalizedStringResource = "\(displayTitle)"

        let stopIntent = StopAlarmIntent(alarmKitID: snoozeID.uuidString)
        let nextSnooze = SnoozeAlarmIntent(
            alarmKitID: snoozeID.uuidString,
            alarmTitle: alarmTitle,
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

        let metadata = AlarmKitMetadata(alarmTitle: alarmTitle, snoozeMinutes: snoozeMinutes)
        let attributes = AlarmAttributes(
            presentation: AlarmPresentation(alert: alert),
            metadata: metadata,
            tintColor: .orange
        )
        let config = AlarmManager.AlarmConfiguration.alarm(
            schedule: .fixed(fireDate),
            attributes: attributes,
            stopIntent: stopIntent,
            secondaryIntent: nextSnooze
        )
        try? await AlarmManager.shared.schedule(id: snoozeID, configuration: config)
        return .result()
    }
}
