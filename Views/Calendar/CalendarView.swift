import SwiftUI
import UIKit

/// Wraps UICalendarView (iOS 16+) in SwiftUI.
/// Shows blue dots on days with alarms, red dots on public holidays.
struct CalendarView: UIViewRepresentable {

    @Binding var selectedDate: DateComponents
    let alarms: [Alarm]
    let holidayService: HolidayService

    // MARK: - UIViewRepresentable

    func makeUIView(context: Context) -> UICalendarView {
        let cv = UICalendarView()
        cv.calendar = .current
        cv.locale = .current
        cv.fontDesign = .rounded
        cv.delegate = context.coordinator

        let selection = UICalendarSelectionSingleDate(delegate: context.coordinator)
        cv.selectionBehavior = selection
        selection.setSelected(selectedDate, animated: false)

        return cv
    }

    func updateUIView(_ uiView: UICalendarView, context: Context) {
        let coord = context.coordinator
        let newToken = refreshToken

        coord.holidayService = holidayService

        if coord.lastRefreshToken != newToken {
            coord.lastRefreshToken = newToken
            coord.alarms = alarms
            // Reload 3 years of decorations so newly added/deleted alarms are reflected
            uiView.reloadDecorations(forDateComponents: dateRange(), animated: true)
        } else {
            coord.alarms = alarms
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(selectedDate: $selectedDate, alarms: alarms, holidayService: holidayService)
    }

    // MARK: - Helpers

    /// A string that changes whenever the set of alarm-date mappings changes.
    private var refreshToken: String {
        alarms
            .map { "\($0.id)-\($0.isEnabled)-\($0.repeatWeekdays.sorted())-\($0.targetDate?.timeIntervalSince1970.rounded() ?? 0)" }
            .joined(separator: "|")
    }

    /// Generates DateComponents for all days in a ±2-year window.
    private func dateRange() -> [DateComponents] {
        let cal = Calendar.current
        let year = cal.component(.year, from: Date())
        var result: [DateComponents] = []
        for y in (year - 1)...(year + 2) {
            for m in 1...12 {
                guard
                    let monthStart = cal.date(from: DateComponents(year: y, month: m)),
                    let daysInMonth = cal.range(of: .day, in: .month, for: monthStart)
                else { continue }
                for d in daysInMonth {
                    result.append(DateComponents(year: y, month: m, day: d))
                }
            }
        }
        return result
    }

    // MARK: - Coordinator

    final class Coordinator: NSObject, UICalendarViewDelegate, UICalendarSelectionSingleDateDelegate {

        @Binding var selectedDate: DateComponents
        var alarms: [Alarm]
        var holidayService: HolidayService
        var lastRefreshToken: String = ""

        init(selectedDate: Binding<DateComponents>, alarms: [Alarm], holidayService: HolidayService) {
            _selectedDate = selectedDate
            self.alarms = alarms
            self.holidayService = holidayService
        }

        // MARK: UICalendarViewDelegate

        func calendarView(
            _ calendarView: UICalendarView,
            decorationFor dateComponents: DateComponents
        ) -> UICalendarView.Decoration? {
            guard let date = Calendar.current.date(from: dateComponents) else { return nil }

            let year = Calendar.current.component(.year, from: date)
            let isHoliday = holidayService.holidays(for: year).contains(date.yyyyMMdd)
            let hasAlarms = alarms.contains { $0.fires(on: date, holidays: holidayService.allHolidays) }

            switch (isHoliday, hasAlarms) {
            case (true, true):
                return .customView {
                    let stack = UIStackView()
                    stack.axis = .horizontal
                    stack.spacing = 3
                    stack.alignment = .center
                    stack.addArrangedSubview(Self.dot(color: .systemRed))
                    stack.addArrangedSubview(Self.dot(color: .systemBlue))
                    return stack
                }
            case (true, false):
                return .default(color: .systemRed, size: .small)
            case (false, true):
                return .default(color: .systemBlue, size: .small)
            default:
                return nil
            }
        }

        // MARK: UICalendarSelectionSingleDateDelegate

        func dateSelection(
            _ selection: UICalendarSelectionSingleDate,
            didSelectDate dateComponents: DateComponents?
        ) {
            if let dc = dateComponents { selectedDate = dc }
        }

        func dateSelection(
            _ selection: UICalendarSelectionSingleDate,
            canSelectDate dateComponents: DateComponents?
        ) -> Bool { true }

        // MARK: Private

        private static func dot(color: UIColor) -> UIView {
            let v = UIView()
            v.backgroundColor = color
            v.layer.cornerRadius = 3
            v.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                v.widthAnchor.constraint(equalToConstant: 6),
                v.heightAnchor.constraint(equalToConstant: 6)
            ])
            return v
        }
    }
}
