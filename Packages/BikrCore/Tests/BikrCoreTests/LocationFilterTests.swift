import Foundation
import Testing
@testable import BikrCore

struct LocationFilterTests {
    let points = Fixtures.northbound(count: 10, step: 10, interval: 2)

    /// Feeds fixes to a fresh filter and returns which were accepted.
    func accepted(_ fixes: [(point: TrackPoint, accuracy: Double)], resetAfter resetIndex: Int? = nil) -> [Bool] {
        var filter = LocationFilter()
        return fixes.enumerated().map { index, fix in
            defer { if index == resetIndex { filter.reset() } }
            return filter.accept(fix.point, horizontalAccuracy: fix.accuracy)
        }
    }

    /// `point` moved `meters` east, keeping its timestamp.
    func shifted(_ point: TrackPoint, by meters: Double) -> TrackPoint {
        var moved = Fixtures.east(of: point, by: meters)
        moved.timestamp = point.timestamp
        return moved
    }

    @Test func dropsImpreciseFixes() {
        #expect(accepted([(points[0], 60), (points[0], -1), (points[0], 5)]) == [false, false, true])
    }

    @Test func dropsJitterWhileStandingStill() {
        // 2 m from the start, two seconds later.
        let jitter = shifted(points[0], by: 2).with(timestamp: points[1].timestamp)
        #expect(accepted([(points[0], 5), (jitter, 5), (points[1], 5)]) == [true, false, true])
    }

    @Test func dropsASingleGlitch() {
        let result = accepted([(points[0], 5), (shifted(points[1], by: 500), 5), (points[2], 5)])
        #expect(result == [true, false, true])
    }

    @Test func recoversWhenTheKeptFixWasTheGlitch() {
        let fixes = [(shifted(points[0], by: 500), 5.0)] + points[1...5].map { ($0, 5.0) }
        #expect(accepted(fixes) == [true, false, false, false, true, true])
    }

    @Test func resetAllowsAJumpAfterAPause() {
        let result = accepted([(points[0], 5), (shifted(points[1], by: 5000), 5)], resetAfter: 0)
        #expect(result == [true, true])
    }
}

private extension TrackPoint {
    func with(timestamp: Date?) -> TrackPoint {
        var copy = self
        copy.timestamp = timestamp
        return copy
    }
}
