import Foundation
import Testing
@testable import BikrCore

struct TrackLibraryTests {
    let route = UUID()

    func summary(_ name: String, runOf: UUID? = nil, distance: Double = 1000,
                 movingTime: TimeInterval = 300, daysAgo: Double = 0) -> TrackSummary {
        var stats = TrackStats()
        stats.distance = distance
        stats.movingTime = movingTime
        return TrackSummary(
            id: runOf == nil ? route : UUID(),
            name: name,
            origin: .recorded,
            createdAt: Fixtures.start.addingTimeInterval(-daysAgo * 86_400),
            runOf: runOf,
            stats: stats
        )
    }

    @Test func separatesRoutesFromTheRunsRiddenOnThem() {
        let library = TrackLibrary([
            summary("Vistula Loop"),
            summary("run", runOf: route, daysAgo: 1),
            summary("run", runOf: route, daysAgo: 2),
            summary("Some other ride", runOf: UUID()),
        ])
        #expect(library.routes.map(\.name) == ["Vistula Loop"])
        #expect(library.runs(of: route).count == 2)
    }

    @Test func listsRunsNewestFirst() {
        let library = TrackLibrary([
            summary("Vistula Loop"),
            summary("older", runOf: route, daysAgo: 5),
            summary("newer", runOf: route, daysAgo: 1),
        ])
        #expect(library.runs(of: route).map(\.name) == ["newer", "older"])
    }

    @Test func theTimeToBeatIsTheQuickestWholeRun() {
        let library = TrackLibrary([
            summary("Vistula Loop", movingTime: 300),
            summary("slower", runOf: route, movingTime: 320),
            summary("quickest", runOf: route, movingTime: 280),
        ])
        #expect(library.bestRun(of: route)?.name == "quickest")
        #expect(library.record(of: route).runs == 2)
        #expect(library.record(of: route).best == 280)
    }

    @Test func aRouteNeverRiddenAgainIsItsOwnTimeToBeat() {
        let library = TrackLibrary([summary("Vistula Loop", movingTime: 300)])
        #expect(library.bestRun(of: route)?.name == "Vistula Loop")
        #expect(library.record(of: route).runs == 0)
    }

    @Test func halfARunIsNoTimeAtAll() {
        let library = TrackLibrary([
            summary("Vistula Loop", distance: 1000, movingTime: 300),
            // Home after 300 m: quick, but not a time on this route.
            summary("gave up", runOf: route, distance: 300, movingTime: 90),
        ])
        #expect(library.bestRun(of: route)?.name == "Vistula Loop")
    }
}
