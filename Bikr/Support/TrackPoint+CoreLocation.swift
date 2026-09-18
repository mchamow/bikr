import BikrCore
import CoreLocation
import MapKit

extension TrackPoint {
    init(_ location: CLLocation) {
        self.init(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            elevation: location.verticalAccuracy > 0 ? location.altitude : nil,
            timestamp: location.timestamp,
            speed: location.speed >= 0 && location.speedAccuracy >= 0 ? location.speed : nil
        )
    }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

extension Track {
    /// The area showing the whole track with some margin around it.
    var mapRect: MKMapRect {
        let coordinates = points.map(\.coordinate)
        let rect = MKPolyline(coordinates: coordinates, count: coordinates.count).boundingMapRect
        let margin = max(rect.width, rect.height) * 0.15 + 300
        return rect.insetBy(dx: -margin, dy: -margin)
    }
}
