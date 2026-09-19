import Foundation

/// The rider's earlier self, riding the same track at the pace they rode it.
///
/// It sets off from wherever the rider joined the track, at the moment they
/// joined, and thereafter goes exactly as fast as the recording did — pauses
/// for a photograph included.
public struct GhostRider: Sendable {
    public let direction: RideDirection
    /// The whole recording, end to end.
    public let totalDistance: Double

    private let points: [TrackPoint]
    /// Distance along the track at each point.
    private let cumulative: [Double]
    /// Seconds from the start of the recording at each point.
    private let seconds: [TimeInterval]
    /// Where in the recording the rider joined it.
    private let joinedAtSecond: TimeInterval

    /// Returns nil for a track that was never ridden — an imported route has
    /// no times in it, so there is no pace to race.
    public init?(segments: [[TrackPoint]], joinedAtAlong along: Double, direction: RideDirection) {
        let points = segments.flatMap(\.self)
        guard points.count > 1, let first = points.first?.timestamp else { return nil }
        var cumulative = [0.0]
        var seconds = [0.0]
        for i in points.indices.dropFirst() {
            guard let time = points[i].timestamp else { return nil }
            cumulative.append(cumulative[i - 1] + points[i - 1].distance(to: points[i]))
            // Never let time run backwards, whatever the clock did.
            seconds.append(max(seconds[i - 1], time.timeIntervalSince(first)))
        }
        self.points = points
        self.cumulative = cumulative
        self.seconds = seconds
        self.direction = direction
        self.totalDistance = cumulative[cumulative.count - 1]
        self.joinedAtSecond = Self.interpolate(along, from: cumulative, to: seconds)
    }

    /// Slower than this (m/s) and the old ride had stopped, whatever its
    /// positions say.
    static let stoppedSpeed = 0.5

    /// How far along the track the ghost has got after `elapsed` seconds.
    public func alongTrack(after elapsed: TimeInterval) -> Double {
        let second = joinedAtSecond + (direction == .against ? -elapsed : elapsed)
        guard let first = seconds.first, let last = seconds.last else { return 0 }
        if second <= first { return cumulative[0] }
        if second >= last { return totalDistance }
        guard let leg = seconds.lastIndex(where: { $0 <= second }), leg + 1 < seconds.count else {
            return totalDistance
        }
        let span = seconds[leg + 1] - seconds[leg]
        let distance = cumulative[leg + 1] - cumulative[leg]
        guard span > 0 else { return cumulative[leg + 1] }
        // Where the old ride barely moved it had stopped: the ghost waits there
        // too, rather than creeping across the gap.
        guard distance / span >= Self.stoppedSpeed else { return cumulative[leg] }
        return cumulative[leg] + (second - seconds[leg]) / span * distance
    }

    /// Where the ghost is after `elapsed` seconds, for drawing it.
    public func position(after elapsed: TimeInterval) -> TrackPoint {
        let along = alongTrack(after: elapsed)
        guard let leg = cumulative.lastIndex(where: { $0 <= along }), leg + 1 < points.count else {
            return points[points.count - 1]
        }
        let span = cumulative[leg + 1] - cumulative[leg]
        let fraction = span > 0 ? (along - cumulative[leg]) / span : 0
        let from = points[leg], to = points[leg + 1]
        return TrackPoint(
            latitude: from.latitude + fraction * (to.latitude - from.latitude),
            longitude: from.longitude + fraction * (to.longitude - from.longitude)
        )
    }

    /// Seconds the rider is ahead of their old self (positive) or behind it
    /// (negative), judged where the rider has got to.
    public func lead(at along: Double, after elapsed: TimeInterval) -> TimeInterval {
        let ghostTook = abs(Self.interpolate(along, from: cumulative, to: seconds) - joinedAtSecond)
        return ghostTook - elapsed
    }

    /// True once the ghost has run out of recording to ride.
    public func hasFinished(after elapsed: TimeInterval) -> Bool {
        let along = alongTrack(after: elapsed)
        return direction == .against ? along <= 0 : along >= totalDistance
    }

    /// Reads one rising series against another, e.g. a time for a distance.
    private static func interpolate(_ value: Double, from: [Double], to: [Double]) -> Double {
        guard let first = from.first, let last = from.last else { return 0 }
        if value <= first { return to[0] }
        if value >= last { return to[to.count - 1] }
        guard let index = from.lastIndex(where: { $0 <= value }), index + 1 < from.count else {
            return to[to.count - 1]
        }
        let span = from[index + 1] - from[index]
        let fraction = span > 0 ? (value - from[index]) / span : 0
        return to[index] + fraction * (to[index + 1] - to[index])
    }
}
