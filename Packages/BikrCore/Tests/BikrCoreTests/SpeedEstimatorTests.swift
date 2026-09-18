import Foundation
import Testing
@testable import BikrCore

struct SpeedEstimatorTests {
    /// 10 m apart, 2 s apart: 5 m/s.
    let points = Fixtures.northbound(count: 5, step: 10, interval: 2)

    func speeds(for points: [TrackPoint]) -> [Double?] {
        var estimator = SpeedEstimator()
        return points.map { estimator.speed(at: $0) }
    }

    @Test func usesTheSpeedGPSReports() {
        let reported = points.map { point in
            var copy = point
            copy.speed = 7
            return copy
        }
        #expect(speeds(for: reported) == [7, 7, 7, 7, 7])
    }

    @Test func worksItOutWhenGPSReportsNone() {
        let result = speeds(for: points)
        #expect(result[0] == nil)
        #expect(result.dropFirst().allSatisfy { abs(($0 ?? 0) - 5) < 0.01 })
    }

    @Test func keepsTheLastEstimateBetweenCloselySpacedFixes() {
        var estimator = SpeedEstimator()
        _ = estimator.speed(at: points[0])
        let measured = estimator.speed(at: points[1])
        // A fix 0.2 s later is too soon to measure with.
        var soon = points[1]
        soon.timestamp = points[1].timestamp?.addingTimeInterval(0.2)
        #expect(estimator.speed(at: soon) == measured)
    }

    @Test func resetForgetsEverything() {
        var estimator = SpeedEstimator()
        for point in points { _ = estimator.speed(at: point) }
        estimator.reset()
        #expect(estimator.speed(at: points[0]) == nil)
    }
}
