import EventKit
import Foundation
import Observation

/// Reads the user's calendar events and auto-creates/removes Alarm entries accordingly.
@Observable
final class CalendarService {
    static let shared = CalendarService()
    private init() {}

    private let store = EKEventStore()
    private(set) var authorizationStatus: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    // MARK: - Permission

    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestFullAccessToEvents()
            await MainActor.run { authorizationStatus = EKEventStore.authorizationStatus(for: .event) }
            return granted
        } catch {
            return false
        }
    }

    var isAuthorized: Bool { authorizationStatus == .fullAccess }

    // MARK: - Scan

    /// Returns upcoming EKEvents within the next `days` calendar days.
    private func upcomingEvents(days: Int = 14) -> [EKEvent] {
        guard isAuthorized else { return [] }
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: days, to: now) ?? now
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        return store.events(matching: predicate).sorted { $0.startDate < $1.startDate }
    }

    // MARK: - Sync

    /// Creates, updates, or deletes alarms to match upcoming calendar events.
    /// - Parameters:
    ///   - alarmStore: The main app's AlarmStore for CRUD operations.
    ///   - leadMinutes: How many minutes before the event to fire the alarm.
    @MainActor
    func syncCalendarAlarms(into alarmStore: AlarmStore, leadMinutes: Int) {
        guard isAuthorized else { return }

        let events = upcomingEvents()
        // Build a lookup of eventID → EKEvent for events that are still upcoming
        let eventsByID: [String: EKEvent] = Dictionary(uniqueKeysWithValues: events.compactMap { e in
            guard let id = e.eventIdentifier else { return nil }
            return (id, e)
        })

        // Collect all alarms that came from calendar events
        let allAlarms = alarmStore.allAlarms
        let calendarAlarms = allAlarms.filter { $0.calendarEventID != nil }

        // Delete auto-created alarms whose event no longer exists or has passed
        for alarm in calendarAlarms {
            guard let eid = alarm.calendarEventID else { continue }
            if eventsByID[eid] == nil {
                alarmStore.delete(alarm)
            }
        }

        // Create or update alarms for upcoming events
        for event in events {
            guard let eid = event.eventIdentifier, let startDate = event.startDate else { continue }
            let alarmTime = startDate.addingTimeInterval(-Double(leadMinutes) * 60)
            guard alarmTime > Date() else { continue }

            if let existing = calendarAlarms.first(where: { $0.calendarEventID == eid }) {
                // Update time if lead changed
                if abs(existing.time.timeIntervalSince(alarmTime)) > 30 {
                    existing.time = alarmTime
                    alarmStore.update(existing)
                }
            } else {
                // Create new alarm
                let alarm = Alarm(
                    title: event.title ?? String(localized: "Event"),
                    time: alarmTime
                )
                alarm.calendarEventID = eid
                alarmStore.add(alarm)
            }
        }
    }
}
