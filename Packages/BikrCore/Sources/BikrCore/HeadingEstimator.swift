import Foundation

/// Which way the rider is going: from GPS when it says so, otherwise from
/// where they have just been. The last answer is kept while they stand still,
/// so a map that turns with them doesn't spin on the spot.
public struct HeadingEstimator: Sendable {
    /// Shorter hops than this (m) say nothing reliable about direction.
    public var minimumMovement = 5.0

    private var lastMeasured: TrackPoint?
    private var lastHeading: Double?

    public init() {}

    public mutating func reset() {
        lastMeasured = nil
        lastHeading = nil
    }

    /// - Parameter course: the course GPS reports, when it is one worth having.
    /// - Returns: degrees from north, or nil until there is anything to go on.
    public mutating func heading(at point: TrackPoint, course: Double? = nil) -> Double? {
        if let course, course >= 0 {
            lastMeasured = point
            lastHeading = course
            return course
        }
        guard let previous = lastMeasured else {
            lastMeasured = point
            return lastHeading
        }
        guard previous.distance(to: point) >= minimumMovement else { return lastHeading }
        lastMeasured = point
        lastHeading = previous.bearing(to: point)
        return lastHeading
    }
}
