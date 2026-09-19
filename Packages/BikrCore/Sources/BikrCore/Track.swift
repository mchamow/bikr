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
    /// The route this was ridden on, when it is one run of many. A track that
    /// stands on its own — the first recording of a route, or an imported one —
    /// has none.
    public var runOf: UUID?
    public var segments: [[TrackPoint]]

    public init(
        id: UUID = UUID(),
        name: String,
        origin: TrackOrigin,
        createdAt: Date = .now,
        runOf: UUID? = nil,
        segments: [[TrackPoint]]
    ) {
        self.id = id
        self.name = name
        self.origin = origin
        self.createdAt = createdAt
        self.runOf = runOf
        self.segments = segments.filter { !$0.isEmpty }
    }

    public var points: [TrackPoint] { segments.flatMap(\.self) }

    public var summary: TrackSummary {
        TrackSummary(id: id, name: name, origin: origin, createdAt: createdAt, runOf: runOf,
                     stats: TrackStats(segments: segments))
    }
}

/// What the track list needs, without loading every point.
public struct TrackSummary: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var origin: TrackOrigin
    public var createdAt: Date
    /// The route this is a run of, if it is one.
    public var runOf: UUID?
    public var stats: TrackStats
}

public extension TrackPoint {
    /// Compass bearing to `other`: degrees clockwise from north, 0..<360.
    func bearing(to other: TrackPoint) -> Double {
        let lat1 = latitude * .pi / 180, lat2 = other.latitude * .pi / 180
        let dLon = (other.longitude - longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let degrees = atan2(y, x) * 180 / .pi
        return degrees < 0 ? degrees + 360 : degrees
    }

    /// How far `other` lies east and north of this point, in meters. Good for
    /// drawing a small area around the rider without a map.
    func offset(to other: TrackPoint) -> (east: Double, north: Double) {
        let planar = other.planar(around: self)
        return (east: planar.x, north: planar.y)
    }

    /// The point `east` and `north` meters away — the inverse of `offset(to:)`,
    /// for panning a drawn map around.
    func moved(east: Double, north: Double) -> TrackPoint {
        let metersPerDegree = 6_371_000.0 * .pi / 180
        var moved = self
        moved.latitude += north / metersPerDegree
        moved.longitude += east / (metersPerDegree * cos(latitude * .pi / 180))
        return moved
    }
}
