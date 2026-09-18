import Foundation

/// Decides which GPS fixes are good enough to become part of a recorded ride.
///
/// The hard case is a bike standing still: the fixes wander, and every wander
/// looks like a short ride. Two things keep that out — GPS is believed when it
/// reports no speed, and a move only counts when it is bigger than the fix's
/// own uncertainty.
public struct LocationFilter: Sendable {
    /// Fixes less precise than this (m) are dropped.
    public var maxHorizontalAccuracy = 25.0
    /// Fixes closer than this (m) to the last kept one are dropped, however
    /// precise they claim to be.
    public var minDistance = 5.0
    /// Below this speed (m/s ≈ 2.5 km/h) the rider is not riding.
    public var stationarySpeed = 0.7
    /// Fixes implying a faster jump than this (m/s) are dropped as glitches.
    public var maxSpeed = 35.0

    /// After this many jumps in a row, the kept fix was probably the glitch.
    static let jumpsBeforeTrustingNewFixes = 3

    private var lastAccepted: TrackPoint?
    private var rejectedJumps = 0

    public init() {}

    /// Forget the last kept fix, e.g. when a new segment starts after a pause.
    public mutating func reset() {
        lastAccepted = nil
        rejectedJumps = 0
    }

    public mutating func accept(_ point: TrackPoint, horizontalAccuracy: Double) -> Bool {
        guard horizontalAccuracy >= 0, horizontalAccuracy <= maxHorizontalAccuracy else { return false }
        // GPS measures speed directly, and knows a standing bike better than
        // any comparison of one position with another.
        if let speed = point.speed, speed >= 0, speed < stationarySpeed { return false }

        if let last = lastAccepted {
            let distance = last.distance(to: point)
            // A fix good to within 12 m says nothing about a 6 m move: that is
            // the fix wandering, not the rider going anywhere.
            guard distance >= max(minDistance, horizontalAccuracy) else { return false }
            if let t0 = last.timestamp, let t1 = point.timestamp {
                let elapsed = t1.timeIntervalSince(t0)
                guard elapsed > 0 else { return false }
                if distance / elapsed > maxSpeed, rejectedJumps < Self.jumpsBeforeTrustingNewFixes {
                    rejectedJumps += 1
                    return false
                }
            }
        }
        lastAccepted = point
        rejectedJumps = 0
        return true
    }
}
