import SwiftUI
import MapKit

/// A searchable sheet for picking a map destination via MKLocalSearch.
struct DestinationPickerView: View {
    @Binding var name: String
    @Binding var latitude: Double
    @Binding var longitude: Double

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [MKMapItem] = []
    @State private var isSearching = false

    var body: some View {
        NavigationStack {
            List {
                if results.isEmpty && !query.isEmpty && !isSearching {
                    ContentUnavailableView.search(text: query)
                }
                ForEach(results, id: \.self) { item in
                    Button { commit(item) } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.name ?? "")
                                .foregroundStyle(.primary)
                            if let subtitle = item.placemark.briefAddress {
                                Text(subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .searchable(text: $query, prompt: Text("Search Destination"))
            .onChange(of: query) { _, value in search(value) }
            .overlay {
                if isSearching { ProgressView() }
            }
            .navigationTitle("Select Destination")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    // MARK: - Private

    private func search(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespaces).isEmpty else {
            results = []
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        isSearching = true
        Task {
            defer { isSearching = false }
            results = (try? await MKLocalSearch(request: request).start())?.mapItems ?? []
        }
    }

    private func commit(_ item: MKMapItem) {
        name      = item.name ?? ""
        latitude  = item.placemark.coordinate.latitude
        longitude = item.placemark.coordinate.longitude
        dismiss()
    }
}

// MARK: - Helpers

private extension MKPlacemark {
    /// A short human-readable address string built from locality components.
    var briefAddress: String? {
        [subLocality, locality, administrativeArea]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
            .nilIfEmpty
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
