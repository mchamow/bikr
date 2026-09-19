import Foundation
import Testing
@testable import BikrCore

struct GhostRiderTests {
    /// 1 km due north at a steady 5 m/s: 10 m every 2 seconds.
    let ride = Fixtures.northbound(count: 101, step: 10, interval: 2)

    func ghost(joinedAtAlong along: Double = 0, direction: RideDirection = .along) throws -> GhostRider {
        try #require(GhostRider(segments: [ride], joinedAtAlong: along, direction: direction))
    }

    @Test func aRouteThatWasNeverRiddenHasNoPaceToRace() {
        let planned = ride.map { TrackPoint(latitude: $0.latitude, longitude: $0.longitude) }
        #expect(GhostRider(segments: [planned], joinedAtAlong: 0, direction: .along) == nil)
    }

    @Test func setsOffFromWhereTheRiderJoined() throws {
        let ghost = try ghost(joinedAtAlong: 400)
        #expect(abs(ghost.alongTrack(after: 0) - 400) < 0.5)
    }

    @Test func ridesAtThePaceItWasRidden() throws {
        let ghost = try ghost()
        // 5 m/s for a minute is 300 m.
        #expect(abs(ghost.alongTrack(after: 60) - 300) < 1)
        let position = ghost.position(after: 60)
        #expect(abs(position.distance(to: ride[30]) ) < 1, "300 m along is the 30th point")
    }

    @Test func leadsWhenTheRiderIsFasterThanTheirOldSelf() throws {
        let ghost = try ghost()
        // The old ride took 60 s to reach 300 m. Getting there in 45 s is 15 s up.
        #expect(abs(ghost.lead(at: 300, after: 45) - 15) < 0.5)
        // Taking 80 s is 20 s down.
        #expect(abs(ghost.lead(at: 300, after: 80) + 20) < 0.5)
    }

    @Test func ridingTheTrackTheOtherWayRunsTheRecordingBackwards() throws {
        let ghost = try ghost(joinedAtAlong: 1000, direction: .against)
        #expect(abs(ghost.alongTrack(after: 60) - 700) < 1)
        #expect(abs(ghost.lead(at: 700, after: 45) - 15) < 0.5)
    }

    @Test func stopsAtTheEndOfTheRecording() throws {
        let ghost = try ghost()
        #expect(!ghost.hasFinished(after: 100))
        #expect(ghost.hasFinished(after: 300), "The whole ride took 200 s")
        #expect(abs(ghost.alongTrack(after: 600) - 1000) < 0.5, "It waits at the end rather than riding on")
    }

    @Test func racesAnEarlierRunOfTheSameRoute() throws {
        // The route as planned, and a run of it ridden at 10 m/s — twice the
        // pace of `ride`, and a few metres to the side of it all the way.
        let route = ride.map { TrackPoint(latitude: $0.latitude, longitude: $0.longitude) }
        let run = Fixtures.northbound(count: 101, step: 10, interval: 1).map { Fixtures.east(of: $0, by: 6).with(timestamp: $0.timestamp) }
        let ghost = try #require(GhostRider(run: [run], on: [route], joinedAtAlong: 0, direction: .along))

        #expect(abs(ghost.alongTrack(after: 30) - 300) < 10, "10 m/s for 30 s is 300 m")
        // The run took 30 s to reach 300 m; taking 40 s is 10 s down on it.
        #expect(abs(ghost.lead(at: 300, after: 40) + 10) < 1)
    }

    @Test func aRunThatNeverWentNearTheRouteIsNoGhost() throws {
        let route = ride
        let elsewhere = Fixtures.northbound(count: 20, step: 10, from: (51, 21))
        #expect(GhostRider(run: [elsewhere], on: [route], joinedAtAlong: 0, direction: .along) == nil)
    }

    @Test func waitsWhereTheOldRideWaited() throws {
        // The old ride stopped for a minute at the 500 m mark.
        var stopped = ride
        for index in 51..<stopped.count {
            stopped[index].timestamp = stopped[index].timestamp?.addingTimeInterval(60)
        }
        let ghost = try #require(GhostRider(segments: [stopped], joinedAtAlong: 0, direction: .along))
        #expect(abs(ghost.alongTrack(after: 100) - 500) < 1)
        #expect(abs(ghost.alongTrack(after: 150) - 500) < 1, "Still standing there")
        #expect(abs(ghost.alongTrack(after: 170) - 550) < 5, "And off again afterwards")
    }
}

private extension TrackPoint {
    func with(timestamp: Date?) -> TrackPoint {
        var copy = self
        copy.timestamp = timestamp
        return copy
    }
}
