import Foundation

/// Current speed for the live display. GPS normally reports one; when it
/// doesn't — the Simulator never does — this works it out from how far the
/// rider moved, and keeps the last estimate between fixes.
public struct SpeedEstimator: Sendable {
    /// Fixes closer together in time than this are too noisy to measure with.
    public var minimumInterval: TimeInterval = 1

    private var lastMeasured: TrackPoint?
    private var lastSpeed: Double?

    public init() {}

    public mutating func reset() {
        lastMeasured = nil
        lastSpeed = nil
    }

    /// m/s, or nil until there is enough to go on.
    public mutating func speed(at point: TrackPoint) -> Double? {
        if let reported = point.speed {
            lastSpeed = reported
            return reported
        }
        guard let previous = lastMeasured, let start = previous.timestamp, let end = point.timestamp else {
            lastMeasured = point
            return lastSpeed
        }
        let elapsed = end.timeIntervalSince(start)
        guard elapsed >= minimumInterval else { return lastSpeed }
        lastMeasured = point
        lastSpeed = previous.distance(to: point) / elapsed
        return lastSpeed
    }
}
