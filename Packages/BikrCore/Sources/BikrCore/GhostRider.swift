import Foundation

/// An earlier ride of the same route, riding it again beside the rider at the
/// pace it was ridden.
///
/// The old ride is measured against the route rather than against itself, so a
/// run that wandered, started halfway or went round the other way can still be
/// raced. The ghost sets off from wherever the rider joined, at the moment they
/// joined.
public struct GhostRider: Sendable {
    /// Slower than this (m/s) and the old ride had stopped, whatever its
    /// positions say.
    static let stoppedSpeed = 0.5
    /// Points of the old ride further than this (m) from the route were not on
    /// it, and say nothing about the pace along it.
    static let onTheRoute = 50.0

    public let direction: RideDirection
    /// The route, end to end.
    public let totalDistance: Double

    private let routePoints: [TrackPoint]
    private let routeCumulative: [Double]
    /// How far along the route the old ride had got, and when.
    private let alongs: [Double]
    private let seconds: [TimeInterval]
    private let joinedAtSecond: TimeInterval

    /// Race an earlier run of the same route.
    /// Returns nil when the run has no times in it, or never went along the route.
    public init?(run: [[TrackPoint]], on route: [[TrackPoint]], joinedAtAlong along: Double, direction: RideDirection) {
        let points = route.flatMap(\.self)
        guard points.count > 1 else { return nil }
        var cumulative = [0.0]
        for i in points.indices.dropFirst() {
            cumulative.append(cumulative[i - 1] + points[i - 1].distance(to: points[i]))
        }
        let total = cumulative[cumulative.count - 1]
        guard let pace = Self.pace(of: run, on: route, totalDistance: total) else { return nil }

        self.routePoints = points
        self.routeCumulative = cumulative
        self.totalDistance = total
        self.alongs = pace.alongs
        self.seconds = pace.seconds
        self.direction = direction
        self.joinedAtSecond = Self.interpolate(along, from: pace.alongs, to: pace.seconds)
    }

    /// Race the recording of the route itself.
    public init?(segments: [[TrackPoint]], joinedAtAlong along: Double, direction: RideDirection) {
        self.init(run: segments, on: segments, joinedAtAlong: along, direction: direction)
    }

    /// How far along the route the ghost has got after `elapsed` seconds.
    public func alongTrack(after elapsed: TimeInterval) -> Double {
        let second = joinedAtSecond + (direction == .against ? -elapsed : elapsed)
        guard let first = seconds.first, let last = seconds.last else { return 0 }
        if second <= first { return alongs[0] }
        if second >= last { return alongs[alongs.count - 1] }
        guard let leg = seconds.lastIndex(where: { $0 <= second }), leg + 1 < seconds.count else {
            return alongs[alongs.count - 1]
        }
        let span = seconds[leg + 1] - seconds[leg]
        let distance = alongs[leg + 1] - alongs[leg]
        guard span > 0 else { return alongs[leg + 1] }
        // Where the old ride barely moved it had stopped: the ghost waits there
        // too, rather than creeping across the gap.
        guard distance / span >= Self.stoppedSpeed else { return alongs[leg] }
        return alongs[leg] + (second - seconds[leg]) / span * distance
    }

    /// Where the ghost is after `elapsed` seconds, for drawing it.
    public func position(after elapsed: TimeInterval) -> TrackPoint {
        var along = alongTrack(after: elapsed)
        // Round a loop more than once, the ghost is still on the same ground.
        if totalDistance > 0, along > totalDistance || along < 0 {
            along -= (along / totalDistance).rounded(.down) * totalDistance
        }
        guard let leg = routeCumulative.lastIndex(where: { $0 <= along }), leg + 1 < routePoints.count else {
            return routePoints[routePoints.count - 1]
        }
        let span = routeCumulative[leg + 1] - routeCumulative[leg]
        let fraction = span > 0 ? (along - routeCumulative[leg]) / span : 0
        let from = routePoints[leg], to = routePoints[leg + 1]
        return TrackPoint(
            latitude: from.latitude + fraction * (to.latitude - from.latitude),
            longitude: from.longitude + fraction * (to.longitude - from.longitude)
        )
    }

    /// Seconds the rider is ahead of the old ride (positive) or behind it
    /// (negative), judged where the rider has got to.
    public func lead(at along: Double, after elapsed: TimeInterval) -> TimeInterval {
        // On a loop the rider's position starts over each lap; bring it onto
        // whichever lap the ghost is riding.
        var riderAlong = along
        if totalDistance > 0 {
            let laps = ((alongTrack(after: elapsed) - along) / totalDistance).rounded()
            riderAlong += laps * totalDistance
        }
        let ghostTook = abs(Self.interpolate(riderAlong, from: alongs, to: seconds) - joinedAtSecond)
        return ghostTook - elapsed
    }

    /// True once the ghost has run out of recording to ride.
    public func hasFinished(after elapsed: TimeInterval) -> Bool {
        let second = joinedAtSecond + (direction == .against ? -elapsed : elapsed)
        return direction == .against ? second <= (seconds.first ?? 0) : second >= (seconds.last ?? 0)
    }

    // MARK: Reading the old ride against the route

    /// How far along the route the old ride was, at each moment of it.
    private static func pace(
        of run: [[TrackPoint]],
        on route: [[TrackPoint]],
        totalDistance: Double
    ) -> (alongs: [Double], seconds: [TimeInterval])? {
        guard var follower = TrackFollower(segments: route) else { return nil }
        var alongs: [Double] = []
        var seconds: [TimeInterval] = []
        var startedAt: Date?
        var lapsAround = 0.0
        var previous: Double?

        for point in run.flatMap(\.self) {
            guard let time = point.timestamp else { continue }
            let status = follower.update(with: point)
            guard status.distanceFromTrack <= Self.onTheRoute else { continue }
            let start = startedAt ?? time
            startedAt = start

            var along = status.alongTrack + lapsAround
            if let previous, totalDistance > 0 {
                // Passing the point where a loop's ends meet is another lap,
                // not a leap back to the beginning.
                if along - previous < -totalDistance / 2 {
                    lapsAround += totalDistance
                    along += totalDistance
                } else if along - previous > totalDistance / 2 {
                    lapsAround -= totalDistance
                    along -= totalDistance
                }
            }
            previous = along
            alongs.append(along)
            seconds.append(time.timeIntervalSince(start))
        }

        guard alongs.count > 1 else { return nil }
        // A run ridden the other way round reads backwards: same ground, same
        // pace, told from the other end.
        if alongs[alongs.count - 1] < alongs[0] {
            let finished = seconds[seconds.count - 1]
            alongs.reverse()
            seconds = seconds.reversed().map { finished - $0 }
        }
        return rising(alongs: alongs, seconds: seconds)
    }

    /// Keeps only the samples that move the ride forwards, so both series rise
    /// together and can be read against each other.
    private static func rising(alongs: [Double], seconds: [TimeInterval]) -> (alongs: [Double], seconds: [TimeInterval])? {
        var keptAlongs: [Double] = []
        var keptSeconds: [TimeInterval] = []
        for (along, second) in zip(alongs, seconds) {
            if let lastAlong = keptAlongs.last, let lastSecond = keptSeconds.last {
                guard along > lastAlong, second > lastSecond else { continue }
            }
            keptAlongs.append(along)
            keptSeconds.append(second)
        }
        return keptAlongs.count > 1 ? (keptAlongs, keptSeconds) : nil
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
