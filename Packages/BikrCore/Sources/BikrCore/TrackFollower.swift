import Foundation

/// Which way along the track the rider is travelling.
public enum RideDirection: String, Sendable, Equatable {
    /// The way the track was recorded or drawn.
    case along
    /// The opposite way.
    case against
}

public struct FollowStatus: Equatable, Sendable {
    /// Meters from the rider to the nearest point of the track.
    public var distanceFromTrack: Double
    /// Nearest point of the track, for drawing a way back when off track.
    public var closestPoint: TrackPoint
    /// Where the rider is along the track, measured from its start.
    public var alongTrack: Double
    /// Meters ridden along the track since joining it.
    public var distanceCovered: Double
    /// Meters to the far end of the track the way the rider is going — or back
    /// to where they joined, on a track whose ends meet.
    public var distanceRemaining: Double
    public var direction: RideDirection
    public var isOffTrack: Bool
    public var isFinished: Bool
}

/// Matches GPS positions to a track and follows progress along it.
///
/// The rider can join the track anywhere and ride it either way: the nearest
/// point of the track wins, and the direction comes from how the rider is
/// actually moving, not from the order the track happens to be stored in.
public struct TrackFollower: Sendable {
    /// Leaving the track by more than this (m) flags the rider as off track...
    public var offTrackDistance = 40.0
    /// ...and they are back on once within this (m).
    public var backOnTrackDistance = 25.0
    /// Within this (m) of the end counts as finished.
    public var finishDistance = 30.0

    /// Ends closer together than this make it a loop, which finishes where the
    /// rider joined rather than at a fixed point.
    static let loopGap = 60.0
    /// Shorter hops than this (m) say nothing reliable about direction.
    static let movementForBearing = 5.0
    /// A bigger step along the track than this (m) is a match somewhere else
    /// entirely, not ground covered.
    static let jumpAlongTrack = 200.0
    /// Two bits of track this close together (m) are the same ground seen
    /// twice — where a route doubles back on itself — and the choice between
    /// them has to be made some other way. Anything wider is simply further
    /// away, and preferring it would leave the rider's progress lagging behind.
    static let sameGround = 2.0

    public let points: [TrackPoint]
    /// Distance along the track at each point.
    private let cumulative: [Double]
    public var totalDistance: Double { cumulative.last ?? 0 }
    public let isLoop: Bool

    private var lastMatch: Match?
    private var lastPosition: TrackPoint?
    private var movementBearing: Double?
    private var direction: RideDirection?
    private var joinedAt: Double?
    private var covered = 0.0
    private var isOffTrack = false

    /// Returns nil for a track without points.
    public init?(segments: [[TrackPoint]]) {
        let points = segments.flatMap(\.self)
        guard !points.isEmpty else { return nil }
        self.points = points
        var cumulative = [0.0]
        for i in points.indices.dropFirst() {
            cumulative.append(cumulative[i - 1] + points[i - 1].distance(to: points[i]))
        }
        self.cumulative = cumulative
        let length = cumulative.last ?? 0
        let endsApart = points[0].distance(to: points[points.count - 1])
        isLoop = length > 500 && endsApart <= Self.loopGap
    }

    public mutating func update(with position: TrackPoint) -> FollowStatus {
        if let previous = lastPosition, previous.distance(to: position) >= Self.movementForBearing {
            movementBearing = previous.bearing(to: position)
        }

        let match = bestMatch(for: position)
        if let previous = lastMatch {
            var step = abs(match.along - previous.along)
            // On a loop, riding past the point where its ends meet is one small
            // step, not a jump the length of the track.
            if isLoop { step = min(step, totalDistance - step) }
            if step < Self.jumpAlongTrack { covered += step }
        }
        joinedAt = joinedAt ?? match.along
        direction = travelDirection(at: match)
        lastMatch = match
        lastPosition = position

        if isOffTrack {
            isOffTrack = match.distance > backOnTrackDistance
        } else {
            isOffTrack = match.distance > offTrackDistance
        }
        let remaining = remainingDistance(from: match.along)

        return FollowStatus(
            distanceFromTrack: match.distance,
            closestPoint: match.point,
            alongTrack: match.along,
            distanceCovered: covered,
            distanceRemaining: remaining,
            direction: direction ?? .along,
            isOffTrack: isOffTrack,
            isFinished: !isOffTrack && isFinished(remaining: remaining, at: match.along)
        )
    }

    // MARK: Where on the track

    private struct Match {
        var leg: Int
        var distance: Double
        var along: Double
        var point: TrackPoint
    }

    private func bestMatch(for position: TrackPoint) -> Match {
        guard points.count > 1 else {
            return Match(leg: 0, distance: position.distance(to: points[0]), along: 0, point: points[0])
        }
        let legs = 0..<(points.count - 1)

        // Continue from the last match, looking the same way back as forward so
        // that turning round is as ordinary as carrying on.
        if let last = lastMatch {
            let window = legs
                .filter { cumulative[$0 + 1] >= last.along - 600 && cumulative[$0] <= last.along + 600 }
                .map { match(position, leg: $0) }
            if let best = window.min(by: { $0.distance < $1.distance }), best.distance <= offTrackDistance {
                return preferred(among: window.filter { $0.distance <= best.distance + Self.sameGround }, near: last) ?? best
            }
        }

        // Otherwise the nearest point of the whole track: the rider joins it
        // wherever they happen to meet it.
        let all = legs.map { match(position, leg: $0) }
        let nearest = all.min { $0.distance < $1.distance }!
        return preferred(among: all.filter { $0.distance <= nearest.distance + Self.sameGround }, near: lastMatch) ?? nearest
    }

    /// Where a track doubles back on itself several legs are equally close.
    /// Prefer the one the rider is travelling along, then the one nearest to
    /// where they were.
    private func preferred(among candidates: [Match], near last: Match?) -> Match? {
        guard candidates.count > 1 else { return candidates.first }
        let facingTheSameWay = movementBearing.map { bearing in
            candidates.filter { angle(between: legBearing($0.leg), and: bearing) < 80 }
        } ?? []
        let choices = facingTheSameWay.isEmpty ? candidates : facingTheSameWay
        guard let last else { return choices.first }
        return choices.min { abs($0.along - last.along) < abs($1.along - last.along) }
    }

    private func match(_ position: TrackPoint, leg: Int) -> Match {
        let a = points[leg], b = points[leg + 1]
        let pa = a.planar(around: position), pb = b.planar(around: position)
        let dx = pb.x - pa.x, dy = pb.y - pa.y
        let lengthSquared = dx * dx + dy * dy
        let t = lengthSquared > 0 ? min(1, max(0, -(pa.x * dx + pa.y * dy) / lengthSquared)) : 0
        let x = pa.x + t * dx, y = pa.y + t * dy
        return Match(
            leg: leg,
            distance: (x * x + y * y).squareRoot(),
            along: cumulative[leg] + t * (cumulative[leg + 1] - cumulative[leg]),
            point: TrackPoint(
                latitude: a.latitude + t * (b.latitude - a.latitude),
                longitude: a.longitude + t * (b.longitude - a.longitude)
            )
        )
    }

    // MARK: Which way, and how much further

    private func legBearing(_ leg: Int) -> Double {
        points[leg].bearing(to: points[min(leg + 1, points.count - 1)])
    }

    /// Smallest angle between two bearings, 0...180.
    private func angle(between one: Double, and other: Double) -> Double {
        let difference = abs(one - other).truncatingRemainder(dividingBy: 360)
        return difference > 180 ? 360 - difference : difference
    }

    private func travelDirection(at match: Match) -> RideDirection {
        guard let movementBearing else {
            // Not moving yet: assume the longer part of the track is the part
            // still to ride.
            return direction ?? (match.along <= totalDistance / 2 ? .along : .against)
        }
        return angle(between: legBearing(match.leg), and: movementBearing) <= 90 ? .along : .against
    }

    private func remainingDistance(from along: Double) -> Double {
        guard totalDistance > 0 else { return 0 }
        if isLoop {
            // A loop ends where the rider joined it, so what's left is however
            // much of its length they have yet to cover.
            return max(0, totalDistance - covered)
        }
        return direction == .against ? max(0, along) : max(0, totalDistance - along)
    }

    private func isFinished(remaining: Double, at along: Double) -> Bool {
        guard remaining <= finishDistance else { return false }
        if isLoop {
            // Back where they joined, having been most of the way round.
            let toJoin = abs(along - (joinedAt ?? 0))
            return covered >= totalDistance * 0.8 && min(toJoin, totalDistance - toJoin) <= finishDistance
        }
        // Not "finished" merely for joining a step away from the end.
        return covered >= 100
    }
}
