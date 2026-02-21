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
        let global: Bool
        let types: [String]
    }

    // MARK: - State

    private(set) var countryCode: String
    private(set) var holidaysByYear: [Int: Set<String>] = [:]
    private var loadingYears: Set<Int> = []

    // MARK: - Init

    init(countryCode: String) {
        self.countryCode = countryCode
        loadFromCache()
    }

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
        let dates: Set<String>
        if countryCode == "CN" {
            dates = try await fetchChinese(year: year)
        } else {
            dates = try await fetchNager(year: year)
        }
        await MainActor.run { [dates] in
            holidaysByYear[year] = dates
            saveToCache()
        }
    }

    /// timor.tech: accurate China data including makeup workdays
    private func fetchChinese(year: Int) async throws -> Set<String> {
        let url = URL(string: "https://timor.tech/api/holiday/year/\(year)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let response = try JSONDecoder().decode(HolidayResponse.self, from: data)
        return Set(
            response.holiday.values
                .filter { $0.holiday }
                .map { $0.date }
        )
    }

    /// Nager.Date: public holidays for 100+ countries
    private func fetchNager(year: Int) async throws -> Set<String> {
        let url = URL(string: "https://date.nager.at/api/v3/PublicHolidays/\(year)/\(countryCode)")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let holidays = try JSONDecoder().decode([NagerHoliday].self, from: data)
        return Set(holidays.filter { $0.global }.map { $0.date })
    }

    // MARK: - Cache (keyed by country code)

    private var cacheKey: String { "HolidayCache_v2_\(countryCode)" }

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
