import CoreLocation

/// Thin async wrapper around CLLocationManager.
/// Call `requestAuthorization()` once on app start; then `currentLocation()` on demand.
final class LocationManager: NSObject, CLLocationManagerDelegate {
    static let shared = LocationManager()

    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocationCoordinate2D, Error>?

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var authorizationStatus: CLAuthorizationStatus { manager.authorizationStatus }

    func requestAuthorization() {
        manager.requestWhenInUseAuthorization()
    }

    /// Returns the device's current coordinate. Throws `CommuteError.locationPermissionDenied`
    /// if the user has not granted location access.
    func currentLocation() async throws -> CLLocationCoordinate2D {
        switch manager.authorizationStatus {
        case .denied, .restricted:
            throw CommuteError.locationPermissionDenied
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            manager.requestLocation()
        }
    }

    // MARK: - CLLocationManagerDelegate

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        continuation?.resume(returning: loc.coordinate)
        continuation = nil
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
