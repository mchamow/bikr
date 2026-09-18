import Foundation
import Testing
@testable import BikrCore

struct TrackFollowerTests {
    /// 1 km due north, a point every 100 m.
    let line = Fixtures.northbound(count: 11, step: 100)

    /// A 1.6 km square starting at its south-west corner, going clockwise.
    var square: [TrackPoint] {
        let side = 400.0, step = 50.0
        let start = TrackPoint(latitude: 50, longitude: 20)
        var points = [start]
        let legs: [(east: Double, north: Double)] = [(0, 1), (1, 0), (0, -1), (-1, 0)]
        var east = 0.0, north = 0.0
        for leg in legs {
            for _ in 0..<Int(side / step) {
                east += leg.east * step
                north += leg.north * step
                points.append(Fixtures.moved(from: start, east: east, north: north))
            }
        }
        return points
    }

    /// Feeds positions to a fresh follower and returns every status.
    func statuses(on segments: [[TrackPoint]], for positions: [TrackPoint]) throws -> [FollowStatus] {
        var follower = try #require(TrackFollower(segments: segments))
        return positions.map { follower.update(with: $0) }
    }

    @Test func emptyTrackCannotBeFollowed() {
        #expect(TrackFollower(segments: []) == nil)
    }

    @Test func reportsProgressAndDistanceFromTheTrack() throws {
        // Halfway between points 3 and 4, 10 m to the east.
        let halfway = TrackPoint(latitude: (line[3].latitude + line[4].latitude) / 2, longitude: line[3].longitude)
        let status = try #require(try statuses(on: [line], for: [Fixtures.east(of: halfway, by: 10)]).first)

        #expect(abs(status.distanceFromTrack - 10) < 0.1)
        #expect(abs(status.closestPoint.latitude - halfway.latitude) < 1e-7)
        #expect(abs(status.distanceRemaining - 650) < 0.5)
        #expect(!status.isOffTrack)
        #expect(!status.isFinished)
    }

    @Test func offTrackUsesHysteresis() throws {
        // 35 m is fine, 45 m is off, back at 30 m still off, 20 m back on.
        let positions = [35.0, 45, 30, 20].map { Fixtures.east(of: line[2], by: $0) }
        let offTrack = try statuses(on: [line], for: positions).map(\.isOffTrack)
        #expect(offTrack == [false, true, true, false])
    }

    @Test func joinsTheTrackWhereverTheRiderMeetsIt() throws {
        // Meeting the track at its 600 m mark and carrying on north.
        let results = try statuses(on: [line], for: [line[6], line[7], line[8]])

        #expect(results[0].distanceCovered == 0, "Joining the track is not ground covered")
        #expect(results.last?.direction == .along)
        #expect(abs((results.last?.distanceRemaining ?? 0) - 200) < 1)
        #expect(abs((results.last?.distanceCovered ?? 0) - 200) < 1)
        #expect(results.allSatisfy { !$0.isOffTrack })
    }

    @Test func ridesTheTrackTheOtherWayRound() throws {
        // From the far end back to the start.
        let results = try statuses(on: [line], for: line.reversed())

        #expect(results.dropFirst().allSatisfy { $0.direction == .against })
        #expect(abs((results[2].distanceRemaining) - 800) < 1)
        #expect(abs((results.last?.distanceCovered ?? 0) - 1000) < 1)
        #expect(results.last?.isFinished == true, "Reaching the start counts as finishing when riding that way")
        #expect(results.dropLast().allSatisfy { !$0.isFinished })
    }

    @Test func doesNotSendTheRiderBackToTheStart() throws {
        // Joining 600 m along and riding on: what's left counts down from 400 m,
        // never the 600 m back to the track's stored start.
        let remaining = try statuses(on: [line], for: [line[6], line[7], line[8], line[9], line[10]])
            .dropFirst()
            .map(\.distanceRemaining)
        #expect(remaining == remaining.sorted(by: >), "Remaining distance has to fall as the rider goes on")
        #expect(abs((remaining.last ?? 99) - 0) < 1)
    }

    @Test func followsATrackThatDoublesBackOnItself() throws {
        let route = line + line.reversed().dropFirst()   // out and back, 2 km
        let ride = line + line.reversed().dropFirst()
        let results = try statuses(on: [route], for: ride)

        #expect(abs((results.last?.distanceCovered ?? 0) - 2000) < 5, "Progress has to keep going on the way back")
        #expect(results.last?.isFinished == true)
        #expect(results.dropLast().allSatisfy { !$0.isFinished })
    }

    @Test func aLoopFinishesWhereTheRiderJoinedIt() throws {
        let loop = square
        var follower = try #require(TrackFollower(segments: [loop]))
        #expect(follower.isLoop)

        // Join a quarter of the way round, ride the whole way round.
        let joinIndex = loop.count / 4
        let ride = Array(loop[joinIndex...]) + Array(loop[...joinIndex].dropFirst())
        let results = ride.map { follower.update(with: $0) }

        #expect(results.last?.isFinished == true)
        #expect(abs((results.last?.distanceCovered ?? 0) - follower.totalDistance) < 30)
        // Passing the track's own start point partway round is not the finish.
        let atStoredStart = results[loop.count - joinIndex - 1]
        #expect(!atStoredStart.isFinished)
    }

    @Test func singlePointTrack() throws {
        let status = try #require(try statuses(on: [[line[0]]], for: [line[1]]).first)
        #expect(abs(status.distanceFromTrack - 100) < 0.5)
        #expect(status.isOffTrack)
    }
}
