import SwiftUI

/// Country picker for selecting the public holiday region.
/// Uses Locale to display localized country names and flag emoji.
struct HolidayRegionPickerView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(AlarmStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    // Build sorted list of (code, localizedName) once
    private let countries: [(code: String, name: String)] = {
        HolidayService.supportedCountries
            .map { item in
                let name = Locale.current.localizedString(forRegionCode: item.code)
                    ?? item.code
                return (code: item.code, name: name)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }()

    private var filtered: [(code: String, name: String)] {
        guard !searchText.isEmpty else { return countries }
        return countries.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        @Bindable var settings = settings

        List(filtered, id: \.code) { country in
            Button {
                settings.holidayCountryCode = country.code
                store.updateHolidayCountry(country.code)
                dismiss()
            } label: {
                HStack {
                    Text(country.code.flagEmoji)
                        .font(.title2)
                        .frame(width: 36)

                    Text(country.name)
                        .foregroundStyle(.primary)

                    Spacer()

                    if settings.holidayCountryCode == country.code {
                        Image(systemName: "checkmark")
                            .foregroundStyle(.tint)
                            .fontWeight(.semibold)
                    }
                }
            }
        }
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle(String(localized: "Holiday Region"))
        .navigationBarTitleDisplayMode(.large)
    }
}

