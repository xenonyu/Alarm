import MapKit
import CoreLocation
import SwiftUI

// MARK: - Errors

enum CommuteError: LocalizedError {
    case locationPermissionDenied
    case noRouteFound

    var errorDescription: String? {
        switch self {
        case .locationPermissionDenied:
            return String(localized: "Location access is required for commute reminders.")
        case .noRouteFound:
            return String(localized: "Could not calculate a route to the destination.")
        }
    }
}

// MARK: - Transport Type

/// Maps to MKDirectionsTransportType while remaining Codable-friendly (stores as Int).
enum CommuteTransportType: Int, CaseIterable, Identifiable {
    case automobile = 0
    case walking    = 1
    case transit    = 2

    var id: Int { rawValue }

    var mkType: MKDirectionsTransportType {
        switch self {
        case .automobile: return .automobile
        case .walking:    return .walking
        case .transit:    return .transit
        }
    }

    var label: LocalizedStringKey {
        switch self {
        case .automobile: return "Driving"
        case .walking:    return "Walking"
        case .transit:    return "Transit"
        }
    }

    var systemImage: String {
        switch self {
        case .automobile: return "car.fill"
        case .walking:    return "figure.walk"
        case .transit:    return "tram.fill"
        }
    }
}

// MARK: - Service

final class CommuteService {
    static let shared = CommuteService()
    private init() {}

    /// Calculates estimated travel time (seconds) from the device's current location
    /// to `coordinate` using the given transport type.
    /// Uses real-time Apple Maps traffic data via MKDirections.
    func travelTime(
        toLatitude latitude: Double,
        longitude: Double,
        using transport: MKDirectionsTransportType
    ) async throws -> TimeInterval {
        let origin      = try await LocationManager.shared.currentLocation()
        let destination = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        let request = MKDirections.Request()
        request.source      = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType  = transport
        request.departureDate  = Date()

        let directions = MKDirections(request: request)

        // MKDirections does not yet expose a native async API; wrap the callback version.
        return try await withCheckedThrowingContinuation { cont in
            directions.calculate { response, error in
                if let error {
                    cont.resume(throwing: error)
                } else if let route = response?.routes.first {
                    cont.resume(returning: route.expectedTravelTime)
                } else {
                    cont.resume(throwing: CommuteError.noRouteFound)
                }
            }
        }
    }
}
