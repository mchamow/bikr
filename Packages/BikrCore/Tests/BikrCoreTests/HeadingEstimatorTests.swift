import Foundation
import Testing
@testable import BikrCore

struct HeadingEstimatorTests {
    /// Due north, 10 m apart.
    let points = Fixtures.northbound(count: 4, step: 10)

    @Test func nothingToGoOnAtTheFirstFix() {
        var estimator = HeadingEstimator()
        #expect(estimator.heading(at: points[0]) == nil)
    }

    @Test func worksItOutFromWhereTheRiderHasBeen() {
        var estimator = HeadingEstimator()
        _ = estimator.heading(at: points[0])
        let heading = estimator.heading(at: points[1])
        #expect(abs((heading ?? -1) - 0) < 0.5, "Riding north reads as 0°")

        let east = Fixtures.east(of: points[1], by: 20)
        #expect(abs((estimator.heading(at: east) ?? -1) - 90) < 0.5)
    }

    @Test func keepsTheLastAnswerWhileStandingStill() {
        var estimator = HeadingEstimator()
        _ = estimator.heading(at: points[0])
        let riding = estimator.heading(at: points[1])
        // A metre of wander is not a change of direction.
        let wander = Fixtures.east(of: points[1], by: 1)
        #expect(estimator.heading(at: wander) == riding)
    }

    @Test func prefersTheCourseGPSReports() {
        var estimator = HeadingEstimator()
        _ = estimator.heading(at: points[0], course: 270)
        #expect(estimator.heading(at: points[1], course: 265) == 265)
    }

    @Test func resetForgetsEverything() {
        var estimator = HeadingEstimator()
        _ = estimator.heading(at: points[0], course: 90)
        estimator.reset()
        #expect(estimator.heading(at: points[1]) == nil)
    }
}
