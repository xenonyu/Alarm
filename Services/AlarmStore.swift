import Foundation
import SwiftData
import Observation

/// Central coordinator: owns HolidayService, bridges SwiftData CRUD with notification scheduling.
@Observable
final class AlarmStore {

    let holidayService = HolidayService()
    private var modelContext: ModelContext?

    // MARK: - Setup

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            let year = Calendar.current.component(.year, from: Date())
            await holidayService.ensureLoaded(for: [year, year + 1])
        }
    }

    // MARK: - CRUD

    func add(_ alarm: Alarm) {
        modelContext?.insert(alarm)
        save()
        Task { await NotificationService.shared.requestPermission() }
        reschedule(alarm)
    }

    func delete(_ alarm: Alarm) {
        Task { await NotificationService.shared.cancel(alarm) }
        modelContext?.delete(alarm)
        save()
    }

    func toggle(_ alarm: Alarm) {
        alarm.isEnabled.toggle()
        save()
        reschedule(alarm)
    }

    func update(_ alarm: Alarm) {
        save()
        reschedule(alarm)
    }

    // MARK: - Helpers

    /// Filters `list` to alarms that fire on the given date.
    func alarms(for date: Date, in list: [Alarm]) -> [Alarm] {
        list.filter { $0.fires(on: date, holidays: holidayService.allHolidays) }
    }

    func hasAlarms(for date: Date, in list: [Alarm]) -> Bool {
        list.contains { $0.fires(on: date, holidays: holidayService.allHolidays) }
    }

    // MARK: - Private

    private func save() {
        try? modelContext?.save()
    }

    private func reschedule(_ alarm: Alarm) {
        Task {
            // Refresh commute travel time from current location before scheduling
            if alarm.commuteEnabled && alarm.commuteLatitude != 0 {
                let transport = CommuteTransportType(rawValue: alarm.commuteTransportType)?.mkType ?? .automobile
                if let travel = try? await CommuteService.shared.travelTime(
                    toLatitude: alarm.commuteLatitude,
                    longitude: alarm.commuteLongitude,
                    using: transport
                ) {
                    await MainActor.run {
                        alarm.commuteTravelSeconds = travel
                        self.save()
                    }
                }
            }

            let holidays = holidayService.allHolidays
            await NotificationService.shared.schedule(alarm, holidays: holidays)
        }
    }
}
