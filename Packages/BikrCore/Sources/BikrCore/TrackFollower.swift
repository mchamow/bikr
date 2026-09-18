import Foundation

public struct FollowStatus: Equatable, Sendable {
    /// Meters from the rider to the nearest point of the track.
    public var distanceFromTrack: Double
    /// Nearest point of the track, for drawing a way back when off track.
    public var closestPoint: TrackPoint
    /// Meters along the track covered so far.
    public var distanceDone: Double
    public var distanceRemaining: Double
    public var isOffTrack: Bool
    public var isFinished: Bool
}

/// Matches GPS positions to a track and tracks progress along it.
public struct TrackFollower: Sendable {
    /// Leaving the track by more than this (m) flags the rider as off track...
    public var offTrackDistance = 40.0
    /// ...and they are back on once within this (m).
    public var backOnTrackDistance = 25.0
    /// Within this (m) of the end counts as finished.
    public var finishDistance = 30.0

    public let points: [TrackPoint]
    /// Distance along the track at each point.
    private let cumulative: [Double]
    public var totalDistance: Double { cumulative.last ?? 0 }

    private var lastMatch: Match?
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
    }

    public mutating func update(with position: TrackPoint) -> FollowStatus {
        let match = bestMatch(for: position)
        lastMatch = match

        if isOffTrack {
            isOffTrack = match.distance > backOnTrackDistance
        } else {
            isOffTrack = match.distance > offTrackDistance
        }
        let remaining = max(0, totalDistance - match.along)
        return FollowStatus(
            distanceFromTrack: match.distance,
            closestPoint: match.point,
            distanceDone: match.along,
            distanceRemaining: remaining,
            isOffTrack: isOffTrack,
            isFinished: !isOffTrack && remaining <= finishDistance
        )
    }

    private struct Match {
        var distance: Double
        var along: Double
        var point: TrackPoint
    }

    private func bestMatch(for position: TrackPoint) -> Match {
        guard points.count > 1 else {
            return Match(distance: position.distance(to: points[0]), along: 0, point: points[0])
        }
        let legs = 0..<(points.count - 1)

        // Prefer continuing from the last match: look a little back and further
        // ahead, and where the track overlaps itself (out-and-back, loops) take
        // the candidate that moves forward the least.
        if let last = lastMatch {
            let from = last.along - 50, to = last.along + 500
            let window = legs
                .filter { cumulative[$0 + 1] >= from && cumulative[$0] <= to }
                .map { match(position, leg: $0) }
            if let best = window.min(by: { $0.distance < $1.distance }), best.distance <= offTrackDistance {
                let forward = window.filter { $0.distance <= best.distance + 10 && $0.along >= last.along - 20 }
                return forward.min { $0.along < $1.along } ?? best
            }
        }

        // Otherwise search everything.
        let all = legs.map { match(position, leg: $0) }
        let nearest = all.min { $0.distance < $1.distance }!
        guard lastMatch == nil else { return nearest }
        // On the very first fix, take the earliest of near-equal candidates so
        // starting an out-and-back or loop route matches its beginning.
        let tolerance = max(nearest.distance + 15, 20)
        return all.first { $0.distance <= tolerance } ?? nearest
    }

    private func match(_ position: TrackPoint, leg: Int) -> Match {
        let a = points[leg], b = points[leg + 1]
        let pa = a.planar(around: position), pb = b.planar(around: position)
        let dx = pb.x - pa.x, dy = pb.y - pa.y
        let lengthSquared = dx * dx + dy * dy
        let t = lengthSquared > 0 ? min(1, max(0, -(pa.x * dx + pa.y * dy) / lengthSquared)) : 0
        let x = pa.x + t * dx, y = pa.y + t * dy
        let point = TrackPoint(
            latitude: a.latitude + t * (b.latitude - a.latitude),
            longitude: a.longitude + t * (b.longitude - a.longitude)
        )
        return Match(
            distance: (x * x + y * y).squareRoot(),
            along: cumulative[leg] + t * (cumulative[leg + 1] - cumulative[leg]),
            point: point
        )
    }
}
