import Foundation
import Testing
@testable import BikrCore

struct TrackFollowerTests {
    /// 1 km due north, a point every 100 m.
    let line = Fixtures.northbound(count: 11, step: 100)

    /// Feeds positions to a fresh follower and returns every status.
    func statuses(on segments: [[TrackPoint]], for positions: [TrackPoint]) throws -> [FollowStatus] {
        var follower = try #require(TrackFollower(segments: segments))
        return positions.map { follower.update(with: $0) }
    }

    @Test func emptyTrackCannotBeFollowed() {
        #expect(TrackFollower(segments: []) == nil)
    }

    @Test func reportsProgressAlongTheTrack() throws {
        // Halfway between points 3 and 4, 10 m to the east.
        let halfway = TrackPoint(latitude: (line[3].latitude + line[4].latitude) / 2, longitude: line[3].longitude)
        let status = try #require(try statuses(on: [line], for: [Fixtures.east(of: halfway, by: 10)]).first)

        #expect(abs(status.distanceFromTrack - 10) < 0.1)
        #expect(abs(status.distanceDone - 350) < 0.5)
        #expect(abs(status.distanceRemaining - 650) < 0.5)
        #expect(abs(status.closestPoint.latitude - halfway.latitude) < 1e-7)
        #expect(!status.isOffTrack)
        #expect(!status.isFinished)
    }

    @Test func offTrackUsesHysteresis() throws {
        // 35 m is fine, 45 m is off, back at 30 m still off, 20 m back on.
        let positions = [35.0, 45, 30, 20].map { Fixtures.east(of: line[2], by: $0) }
        let offTrack = try statuses(on: [line], for: positions).map(\.isOffTrack)
        #expect(offTrack == [false, true, true, false])
    }

    @Test func finishesNearTheEnd() throws {
        let finished = try statuses(on: [line], for: [line[9], line[10]]).map(\.isFinished)
        #expect(finished == [false, true])
    }

    @Test func outAndBackStartsAtTheBeginningAndKeepsProgress() throws {
        let route = line + line.reversed().dropFirst()   // 2 km, ends where it starts
        // Out to the turnaround and back, over the very same spots.
        let ride = line + line.reversed().dropFirst()
        let results = try statuses(on: [route], for: ride)

        let done = results.map { ($0.distanceDone / 100).rounded() }
        #expect(done == (0...20).map(Double.init))
        #expect(results.dropLast().allSatisfy { !$0.isFinished })
        #expect(results.last?.isFinished == true)
    }

    @Test func singlePointTrack() throws {
        let status = try #require(try statuses(on: [[line[0]]], for: [line[1]]).first)
        #expect(abs(status.distanceFromTrack - 100) < 0.5)
        #expect(status.isOffTrack)
    }
}
