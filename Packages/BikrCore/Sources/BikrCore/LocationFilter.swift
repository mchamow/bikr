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
    /// The fix a ride starts from must be better than this (m). In the first
    /// half-minute GPS is still settling, and every later distance is measured
    /// from wherever the ride was anchored.
    public var maxAccuracyForFirstFix = 15.0
    /// Fixes closer than this (m) to the last kept one are dropped, however
    /// precise they claim to be.
    public var minDistance = 5.0
    /// Below this speed (m/s ≈ 2.5 km/h) the rider is not riding.
    public var stationarySpeed = 0.7
    /// Fixes implying a faster jump than this (m/s) are dropped as glitches.
    public var maxSpeed = 35.0
    /// The hardest a bicycle accelerates (m/s²). A fix implying more than this
    /// is the GPS jumping, not the rider sprinting: 20 m in a second from a
    /// standing start is 74 km/h, which no one does.
    public var maxAcceleration = 3.0

    /// After this many jumps in a row, the kept fix was probably the glitch.
    static let jumpsBeforeTrustingNewFixes = 3

    private var lastAccepted: TrackPoint?
    /// How fast the rider was going at the last kept fix.
    private var lastSpeed = 0.0
    private var rejectedJumps = 0

    public init() {}

    /// Forget the last kept fix, e.g. when a new segment starts after a pause.
    public mutating func reset() {
        lastAccepted = nil
        lastSpeed = 0
        rejectedJumps = 0
    }

    public mutating func accept(_ point: TrackPoint, horizontalAccuracy: Double) -> Bool {
        guard horizontalAccuracy >= 0, horizontalAccuracy <= maxHorizontalAccuracy else { return false }
        // GPS measures speed directly, and knows a standing bike better than
        // any comparison of one position with another.
        if let speed = point.speed, speed >= 0, speed < stationarySpeed { return false }

        guard lastAccepted != nil || horizontalAccuracy <= maxAccuracyForFirstFix else { return false }

        if let last = lastAccepted {
            let distance = last.distance(to: point)
            // A fix good to within 12 m says nothing about a 6 m move: that is
            // the fix wandering, not the rider going anywhere.
            guard distance >= max(minDistance, horizontalAccuracy) else { return false }
            if let t0 = last.timestamp, let t1 = point.timestamp {
                let elapsed = t1.timeIntervalSince(t0)
                guard elapsed > 0 else { return false }
                let implied = distance / elapsed
                let fastestPossible = min(maxSpeed, lastSpeed + maxAcceleration * elapsed)
                if implied > fastestPossible, rejectedJumps < Self.jumpsBeforeTrustingNewFixes {
                    rejectedJumps += 1
                    return false
                }
                // Never carry forward a speed that was itself implausible.
                lastSpeed = point.speed ?? min(implied, fastestPossible)
            }
        }
        // A rolling start: GPS knows the rider was already moving.
        if lastAccepted == nil {
            lastSpeed = point.speed ?? 0
        }
        lastAccepted = point
        rejectedJumps = 0
        return true
    }
}
