import CoreLocation
import Foundation

/// Future OBD and external GNSS adapters can deliver the same point interface.
@MainActor
protocol PositionSource: AnyObject {
    var onPoint: ((GPSPoint) -> Void)? { get set }
    func start()
    func stop()
}

@MainActor
final class LocationEngine: NSObject, PositionSource, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var requested = false
    var onPoint: ((GPSPoint) -> Void)?
    var onStatus: ((String, Bool) -> Void)?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone
        manager.activityType = .automotiveNavigation
        manager.pausesLocationUpdatesAutomatically = false
        manager.showsBackgroundLocationIndicator = true
    }

    func start() {
        requested = true
        if manager.authorizationStatus == .notDetermined {
            manager.requestWhenInUseAuthorization()
        } else { updateAuthorization() }
    }

    func stop() {
        requested = false
        manager.stopUpdatingLocation()
        manager.allowsBackgroundLocationUpdates = false
    }

    func requestPreciseLocation() {
        manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "RallyMeasurement")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) { updateAuthorization() }

    private func updateAuthorization() {
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            let precise = manager.accuracyAuthorization == .fullAccuracy
            onStatus?(precise ? "GPS wird gesucht" : "Genauer Standort ist deaktiviert", precise)
            if requested {
                manager.allowsBackgroundLocationUpdates = true
                manager.startUpdatingLocation()
            }
        case .denied, .restricted:
            onStatus?("Standortzugriff fehlt – in den iPhone-Einstellungen erlauben", false)
        case .notDetermined:
            onStatus?("Standortfreigabe erforderlich", false)
        @unknown default:
            onStatus?("Standort nicht verfügbar", false)
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard requested else { return }
        for location in locations {
            onPoint?(GPSPoint(latitude: location.coordinate.latitude,
                              longitude: location.coordinate.longitude,
                              altitude: location.altitude, speedMPS: location.speed,
                              course: location.course, accuracy: location.horizontalAccuracy,
                              timestamp: location.timestamp))
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onStatus?("GPS: \(error.localizedDescription)", false)
    }
}
