import Foundation
@testable import BikrCore

enum Fixtures {
    static let start = Date(timeIntervalSince1970: 1_800_000_000)
    /// Meters per degree of latitude on the sphere `TrackPoint` uses.
    static let metersPerDegree = 6_371_000.0 * .pi / 180

    /// A ride due north from (50, 20): one point every `step` meters and
    /// `interval` seconds.
    static func northbound(
        count: Int,
        step: Double = 10,
        interval: TimeInterval = 2,
        from origin: (lat: Double, lon: Double) = (50, 20),
        startingAt start: Date = start,
        elevation: (Int) -> Double? = { _ in nil }
    ) -> [TrackPoint] {
        (0..<count).map { i in
            TrackPoint(
                latitude: origin.lat + Double(i) * step / metersPerDegree,
                longitude: origin.lon,
                elevation: elevation(i),
                timestamp: start.addingTimeInterval(Double(i) * interval)
            )
        }
    }

    /// A point `meters` east of `point`.
    static func east(of point: TrackPoint, by meters: Double) -> TrackPoint {
        TrackPoint(
            latitude: point.latitude,
            longitude: point.longitude + meters / (metersPerDegree * cos(point.latitude * .pi / 180))
        )
    }
}
