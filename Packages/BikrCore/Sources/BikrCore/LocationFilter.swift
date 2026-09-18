import Foundation

/// Decides which GPS fixes are good enough to become part of a recorded ride.
public struct LocationFilter: Sendable {
    /// Fixes less precise than this (m) are dropped.
    public var maxHorizontalAccuracy = 25.0
    /// Fixes closer than this (m) to the last kept one are dropped, so standing
    /// still doesn't pile up jittery points.
    public var minDistance = 5.0
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
        if let last = lastAccepted {
            let distance = last.distance(to: point)
            guard distance >= minDistance else { return false }
            if let t0 = last.timestamp, let t1 = point.timestamp {
                let dt = t1.timeIntervalSince(t0)
                guard dt > 0 else { return false }
                if distance / dt > maxSpeed, rejectedJumps < Self.jumpsBeforeTrustingNewFixes {
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
