import Foundation
import SwiftData
import Observation
import WidgetKit

/// Central coordinator: owns HolidayService, bridges SwiftData CRUD with notification scheduling.
@Observable
final class AlarmStore {

    let holidayService = HolidayService(countryCode: AppSettings.shared.holidayCountryCode)
    private var modelContext: ModelContext?

    // MARK: - Setup

    func setup(modelContext: ModelContext) {
        self.modelContext = modelContext
        Task {
            let year = Calendar.current.component(.year, from: Date())
            await holidayService.ensureLoaded(for: [year, year + 1])
        }
    }

    /// Switch the holiday country and reschedule all alarms.
    func updateHolidayCountry(_ code: String) {
        holidayService.updateCountry(code)
        Task {
            let year = Calendar.current.component(.year, from: Date())
            await holidayService.ensureLoaded(for: [year, year + 1])
            await rescheduleAll()
        }
    }

    /// Reschedule notifications for every alarm (e.g. after country change).
    func rescheduleAll() async {
        guard let ctx = modelContext else { return }
        let descriptor = FetchDescriptor<Alarm>()
        let alarms = (try? ctx.fetch(descriptor)) ?? []
        let holidays = holidayService.allHolidays
        for alarm in alarms {
            await NotificationService.shared.schedule(alarm, holidays: holidays)
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
        writeWidgetSnapshot()
    }

    private func writeWidgetSnapshot() {
        guard let ctx = modelContext else { return }
        let allAlarms = (try? ctx.fetch(FetchDescriptor<Alarm>())) ?? []
        let holidays = holidayService.allHolidays
        let now = Date()
        let next = allAlarms
            .filter(\.isEnabled)
            .compactMap { alarm -> (Date, Alarm)? in
                guard let d = alarm.nextFireDates(from: now, count: 1, holidays: holidays).first else { return nil }
                return (d, alarm)
            }
            .min(by: { $0.0 < $1.0 })
        let snapshot = AlarmWidgetSnapshot(
            nextAlarmTime: next?.0,
            nextAlarmTitle: next?.1.title ?? "",
            nextAlarmRepeatLabel: ""
        )
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
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
