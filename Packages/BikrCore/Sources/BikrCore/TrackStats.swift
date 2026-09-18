import Foundation

public struct TrackStats: Codable, Hashable, Sendable {
    /// Meters.
    public var distance: Double = 0
    /// Seconds from the first to the last timestamp, pauses included.
    public var elapsedTime: TimeInterval = 0
    /// Seconds spent actually moving.
    public var movingTime: TimeInterval = 0
    /// m/s.
    public var maxSpeed: Double = 0
    /// Meters climbed.
    public var elevationGain: Double = 0

    /// m/s over moving time. A couple of seconds of riding says nothing about
    /// an average, and one bad fix would make it absurd, so it stays at zero
    /// until there is something to average.
    public var averageSpeed: Double { movingTime >= 5 ? distance / movingTime : 0 }

    public static let zero = TrackStats()

    public init() {}

    public init(segments: [[TrackPoint]]) {
        var accumulator = StatsAccumulator()
        for segment in segments {
            accumulator.startSegment()
            segment.forEach { accumulator.add($0) }
        }
        self = accumulator.stats
    }
}

/// Builds `TrackStats` one point at a time, so a live ride doesn't rescan
/// every point on each GPS fix.
public struct StatsAccumulator: Sendable {
    /// Below this speed (m/s) the rider counts as stopped.
    static let movingSpeed = 0.5
    /// Faster than this (m/s) is treated as a GPS glitch.
    static let implausibleSpeed = 35.0
    /// Altitude changes smaller than this (m) are treated as GPS noise.
    static let elevationNoise = 4.0

    public private(set) var stats = TrackStats.zero
    private var previous: TrackPoint?
    private var firstTimestamp: Date?
    private var elevationReference: Double?

    public init() {}

    /// Call before the first point of every segment after the first.
    public mutating func startSegment() {
        previous = nil
        elevationReference = nil
    }

    public mutating func add(_ point: TrackPoint) {
        defer { previous = point }

        if let time = point.timestamp {
            let first = firstTimestamp ?? time
            firstTimestamp = first
            stats.elapsedTime = max(stats.elapsedTime, time.timeIntervalSince(first))
        }
        if let gpsSpeed = point.speed, gpsSpeed >= 0, gpsSpeed < Self.implausibleSpeed {
            stats.maxSpeed = max(stats.maxSpeed, gpsSpeed)
        }
        addElevation(point.elevation)

        guard let previous else { return }
        let distance = previous.distance(to: point)
        stats.distance += distance

        guard let t0 = previous.timestamp, let t1 = point.timestamp else { return }
        let dt = t1.timeIntervalSince(t0)
        guard dt > 0 else { return }
        let speed = distance / dt
        if speed >= Self.movingSpeed {
            stats.movingTime += dt
        }
        // Imported tracks often lack GPS speed, so fall back to computed speed.
        if point.speed == nil, speed < Self.implausibleSpeed {
            stats.maxSpeed = max(stats.maxSpeed, speed)
        }
    }

    private mutating func addElevation(_ elevation: Double?) {
        guard let elevation else { return }
        guard let reference = elevationReference else {
            elevationReference = elevation
            return
        }
        let change = elevation - reference
        if change >= Self.elevationNoise {
            stats.elevationGain += change
            elevationReference = elevation
        } else if change <= -Self.elevationNoise {
            elevationReference = elevation
        }
    }
}
