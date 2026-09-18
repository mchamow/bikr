import Foundation
import Testing
@testable import BikrCore

struct TrackStatsTests {
    @Test func distanceAndTimesForSteadyRide() {
        // 101 points, 10 m apart, every 2 s: 1 km in 200 s at 5 m/s.
        let stats = TrackStats(segments: [Fixtures.northbound(count: 101)])
        #expect(abs(stats.distance - 1000) < 0.5)
        #expect(stats.elapsedTime == 200)
        #expect(stats.movingTime == 200)
        #expect(abs(stats.averageSpeed - 5) < 0.01)
        #expect(abs(stats.maxSpeed - 5) < 0.01)
    }

    @Test func pauseBetweenSegmentsAddsNoDistanceOrMovingTime() {
        let first = Fixtures.northbound(count: 11)
        // Resumed 10 minutes later, 2 km further north (e.g. a lift in a car).
        let second = Fixtures.northbound(
            count: 11, from: (50 + 3000 / Fixtures.metersPerDegree, 20),
            startingAt: Fixtures.start.addingTimeInterval(600)
        )
        let stats = TrackStats(segments: [first, second])
        #expect(abs(stats.distance - 200) < 0.5)
        #expect(stats.movingTime == 40)
        #expect(stats.elapsedTime == 620)
    }

    @Test func standingStillIsNotMovingTime() {
        var points = Fixtures.northbound(count: 2)
        // Same place, a minute later.
        var stopped = points[1]
        stopped.timestamp = points[1].timestamp!.addingTimeInterval(60)
        points.append(stopped)
        let stats = TrackStats(segments: [points])
        #expect(stats.movingTime == 2)
        #expect(stats.elapsedTime == 62)
    }

    @Test func gpsSpeedWinsOverComputedSpeed() {
        var points = Fixtures.northbound(count: 3)
        points = points.map { var p = $0; p.speed = 7; return p }
        #expect(TrackStats(segments: [points]).maxSpeed == 7)
    }

    @Test func glitchySpeedsAreIgnored() {
        var points = Fixtures.northbound(count: 3)
        points[1].speed = 90
        #expect(TrackStats(segments: [points]).maxSpeed < 35)
    }

    @Test func elevationGainIgnoresNoise() {
        // ±2 m jitter around 100 m, then a real 30 m climb.
        let jitter = [100, 102, 98, 101, 99, 102, 100.0]
        let climb = [110, 120, 130.0]
        let elevations = jitter + climb
        let points = Fixtures.northbound(count: elevations.count) { elevations[$0] }
        let gain = TrackStats(segments: [points]).elevationGain
        #expect(gain >= 28 && gain <= 32)
    }

    @Test func emptyTrackHasZeroStats() {
        #expect(TrackStats(segments: []) == .zero)
        #expect(TrackStats(segments: [[]]) == .zero)
    }
}
