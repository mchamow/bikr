import Foundation

/// One GPS fix along a track.
public struct TrackPoint: Codable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double
    /// Meters above sea level, when known.
    public var elevation: Double?
    public var timestamp: Date?
    /// Speed reported by GPS in m/s, when known.
    public var speed: Double?

    public init(latitude: Double, longitude: Double, elevation: Double? = nil, timestamp: Date? = nil, speed: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.timestamp = timestamp
        self.speed = speed
    }

    // Short keys keep long rides small on disk.
    private enum CodingKeys: String, CodingKey {
        case latitude = "lat", longitude = "lon", elevation = "ele", timestamp = "t", speed = "v"
    }

    private static let earthRadius = 6_371_000.0

    /// Great-circle distance in meters.
    public func distance(to other: TrackPoint) -> Double {
        let lat1 = latitude * .pi / 180, lat2 = other.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (other.longitude - longitude) * .pi / 180
        let a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * Self.earthRadius * atan2(a.squareRoot(), (1 - a).squareRoot())
    }

    /// Position in meters on a flat plane centered at `origin`. Accurate enough
    /// for the short distances used when matching a rider to a track.
    func planar(around origin: TrackPoint) -> (x: Double, y: Double) {
        let metersPerDegree = Self.earthRadius * .pi / 180
        return (
            x: (longitude - origin.longitude) * metersPerDegree * cos(origin.latitude * .pi / 180),
            y: (latitude - origin.latitude) * metersPerDegree
        )
    }
}

public enum TrackOrigin: String, Codable, Sendable {
    /// Recorded with Bikr.
    case recorded
    /// Imported from a GPX file.
    case imported
}

/// A recorded ride or an imported route. A new segment starts whenever
/// recording is paused and resumed, mirroring GPX `<trkseg>`.
public struct Track: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var origin: TrackOrigin
    public var createdAt: Date
    public var segments: [[TrackPoint]]

    public init(id: UUID = UUID(), name: String, origin: TrackOrigin, createdAt: Date = .now, segments: [[TrackPoint]]) {
        self.id = id
        self.name = name
        self.origin = origin
        self.createdAt = createdAt
        self.segments = segments.filter { !$0.isEmpty }
    }

    public var points: [TrackPoint] { segments.flatMap(\.self) }

    public var summary: TrackSummary {
        TrackSummary(id: id, name: name, origin: origin, createdAt: createdAt, stats: TrackStats(segments: segments))
    }
}

/// What the track list needs, without loading every point.
public struct TrackSummary: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var origin: TrackOrigin
    public var createdAt: Date
    public var stats: TrackStats
}
