import Foundation
import Observation

/// Fetches and caches public holiday data for a configurable country.
/// - China (CN): timor.tech API — handles makeup workdays accurately
/// - All others: Nager.Date API (https://date.nager.at) — 100+ countries
@Observable
final class HolidayService {

    // MARK: - Nager.Date response model

    private struct NagerHoliday: Codable {
        let date: String        // "YYYY-MM-DD"
        let name: String
        let localName: String
        let global: Bool
        let types: [String]
    }

    // MARK: - State

    private(set) var countryCode: String
    /// Maps year → { "YYYY-MM-DD" → holiday name }
    private(set) var holidaysByYear: [Int: [String: String]] = [:]
    /// Increments each time holiday data loads; used to trigger CalendarView decoration refresh.
    private(set) var holidayVersion: Int = 0
    private var loadingYears: Set<Int> = []

    // MARK: - Init

    init(countryCode: String) {
        self.countryCode = countryCode
        loadFromCache()
    }

    // MARK: - Public API

    var allHolidays: Set<String> {
        holidaysByYear.values.reduce(Set<String>()) { $0.union(Set($1.keys)) }
    }

    func holidays(for year: Int) -> Set<String> {
        guard let dict = holidaysByYear[year] else { return [] }
        return Set(dict.keys)
    }

    func isHoliday(_ date: Date) -> Bool {
        let year = Calendar.current.component(.year, from: date)
        return holidaysByYear[year]?[date.yyyyMMdd] != nil
    }

    /// Returns the localized holiday name for the given date, or nil if not a holiday.
    func holidayName(for date: Date) -> String? {
        let year = Calendar.current.component(.year, from: date)
        return holidaysByYear[year]?[date.yyyyMMdd]
    }

    /// Switch country: clears cached data and reloads from cache for new country.
    func updateCountry(_ code: String) {
        guard code != countryCode else { return }
        countryCode = code
        holidaysByYear = [:]
        loadingYears = []
        loadFromCache()
    }

    /// Ensures holidays are loaded for all requested years (fetches missing ones).
    func ensureLoaded(for years: Set<Int>) async {
        for year in years where holidaysByYear[year] == nil && !loadingYears.contains(year) {
            loadingYears.insert(year)
            do {
                try await fetchHolidays(for: year)
            } catch {
                print("[HolidayService] Failed to fetch \(countryCode)/\(year): \(error)")
            }
            loadingYears.remove(year)
        }
    }

    // MARK: - Network

    private func fetchHolidays(for year: Int) async throws {
        let namesByDate: [String: String]
        if countryCode == "CN" {
            namesByDate = try await fetchChinese(year: year)
        } else {
            namesByDate = try await fetchNager(year: year)
        }
        await MainActor.run { [namesByDate] in
            holidaysByYear[year] = namesByDate
            holidayVersion += 1
            saveToCache()
        }
    }

    /// timor.tech: accurate China data including makeup workdays
    private func fetchChinese(year: Int) async throws -> [String: String] {
        let url = URL(string: "https://timor.tech/api/holiday/year/\(year)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(HolidayResponse.self, from: data)
        var result: [String: String] = [:]
        for entry in response.holiday.values where entry.holiday {
            result[entry.date] = entry.name
        }
        return result
    }

    /// Nager.Date: public holidays for 100+ countries
    private func fetchNager(year: Int) async throws -> [String: String] {
        let url = URL(string: "https://date.nager.at/api/v3/PublicHolidays/\(year)/\(countryCode)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let holidays = try JSONDecoder().decode([NagerHoliday].self, from: data)
        var result: [String: String] = [:]
        for h in holidays where h.global {
            result[h.date] = h.localName.isEmpty ? h.name : h.localName
        }
        return result
    }

    // MARK: - Cache (keyed by country code, v3 includes holiday names)

    private var cacheKey: String { "HolidayCache_v3_\(countryCode)" }

    private var groupDefaults: UserDefaults { UserDefaults(suiteName: appGroupID) ?? .standard }

    private func loadFromCache() {
        guard
            let data = groupDefaults.data(forKey: cacheKey),
            let decoded = try? JSONDecoder().decode([Int: [String: String]].self, from: data)
        else { return }
        holidaysByYear = decoded
        if !decoded.isEmpty { holidayVersion += 1 }
    }

    private func saveToCache() {
        if let data = try? JSONEncoder().encode(holidaysByYear) {
            groupDefaults.set(data, forKey: cacheKey)
        }
    }

    // MARK: - Supported Countries

    /// All countries supported by this service.
    /// CN uses timor.tech; all others use Nager.Date.
    static let supportedCountries: [(code: String, nager: Bool)] = [
        ("AD", true), ("AL", true), ("AM", true), ("AR", true), ("AT", true),
        ("AU", true), ("BE", true), ("BG", true), ("BO", true), ("BR", true),
        ("BS", true), ("BW", true), ("BY", true), ("CA", true), ("CH", true),
        ("CL", true), ("CN", false), ("CO", true), ("CR", true), ("CY", true),
        ("CZ", true), ("DE", true), ("DK", true), ("DO", true), ("EC", true),
        ("EE", true), ("EG", true), ("ES", true), ("FI", true), ("FR", true),
        ("GB", true), ("GH", true), ("GR", true), ("GT", true), ("HK", true),
        ("HN", true), ("HR", true), ("HU", true), ("ID", true), ("IE", true),
        ("IL", true), ("IN", true), ("IS", true), ("IT", true), ("JM", true),
        ("JP", true), ("KE", true), ("KR", true), ("KW", true), ("KZ", true),
        ("LA", true), ("LI", true), ("LT", true), ("LU", true), ("LV", true),
        ("MA", true), ("MD", true), ("MK", true), ("MN", true), ("MT", true),
        ("MX", true), ("MY", true), ("NA", true), ("NG", true), ("NI", true),
        ("NL", true), ("NO", true), ("NZ", true), ("PA", true), ("PE", true),
        ("PH", true), ("PK", true), ("PL", true), ("PT", true), ("PY", true),
        ("RO", true), ("RS", true), ("RU", true), ("SA", true), ("SE", true),
        ("SG", true), ("SI", true), ("SK", true), ("SM", true), ("SV", true),
        ("TN", true), ("TR", true), ("TT", true), ("TZ", true), ("UA", true),
        ("UG", true), ("US", true), ("UY", true), ("UZ", true), ("VA", true),
        ("VE", true), ("VN", true), ("ZA", true), ("ZW", true),
    ]
}
