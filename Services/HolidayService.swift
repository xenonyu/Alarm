import Foundation
import Observation

/// Fetches and caches Chinese public holiday data from timor.tech API.
/// holiday: true  → official day off (skip this date when scheduling)
/// holiday: false → makeup workday (regular working day, do NOT skip)
@Observable
final class HolidayService {

    private(set) var holidaysByYear: [Int: Set<String>] = [:]
    private var loadingYears: Set<Int> = []
    private let cacheKey = "HolidayCache_v1"

    init() { loadFromCache() }

    // MARK: - Public API

    var allHolidays: Set<String> {
        holidaysByYear.values.reduce(Set<String>()) { $0.union($1) }
    }

    func holidays(for year: Int) -> Set<String> {
        holidaysByYear[year] ?? []
    }

    func isHoliday(_ date: Date) -> Bool {
        let year = Calendar.current.component(.year, from: date)
        return holidaysByYear[year]?.contains(date.yyyyMMdd) ?? false
    }

    /// Ensures holidays are loaded for all requested years (fetches missing ones).
    func ensureLoaded(for years: Set<Int>) async {
        for year in years where holidaysByYear[year] == nil && !loadingYears.contains(year) {
            loadingYears.insert(year)
            do {
                try await fetchHolidays(for: year)
            } catch {
                print("[HolidayService] Failed to fetch \(year): \(error)")
            }
            loadingYears.remove(year)
        }
    }

    // MARK: - Network

    private func fetchHolidays(for year: Int) async throws {
        let url = URL(string: "https://timor.tech/api/holiday/year/\(year)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(HolidayResponse.self, from: data)

        // Build the set before jumping to MainActor to avoid sendable capture of var
        let holidays: Set<String> = Set(
            response.holiday.values
                .filter { $0.holiday }
                .map { $0.date }
        )

        await MainActor.run { [holidays] in
            holidaysByYear[year] = holidays
            saveToCache()
        }
    }

    // MARK: - Cache

    private func loadFromCache() {
        guard
            let data = UserDefaults.standard.data(forKey: cacheKey),
            let decoded = try? JSONDecoder().decode([Int: [String]].self, from: data)
        else { return }
        holidaysByYear = decoded.mapValues { Set($0) }
    }

    private func saveToCache() {
        let dict = holidaysByYear.mapValues { Array($0) }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }
}
