import Foundation
import Testing
@testable import BikrCore

struct RideDraftTests {
    let url = FileManager.default.temporaryDirectory
        .appending(path: "BikrDraftTests-\(UUID())")
        .appending(path: "ride.jsonl")
    let points = Fixtures.northbound(count: 5, step: 10, interval: 2)

    func draft() -> RideDraft { RideDraft(url: url) }

    @Test func nothingToRecoverWithoutADraft() {
        #expect(draft().recover() == nil)
    }

    @Test func recoversEveryPointWrittenSoFar() {
        let writer = draft()
        writer.start(at: Fixtures.start)
        points.forEach { writer.append($0) }

        // A separate reader, as after a relaunch.
        let recovered = draft().recover()
        #expect(recovered?.startedAt == Fixtures.start)
        #expect(recovered?.segments == [points])
        #expect(abs((recovered?.stats.distance ?? 0) - 40) < 0.5)
    }

    @Test func keepsSegmentsFromPauses() {
        let writer = draft()
        writer.start(at: Fixtures.start)
        points[0...1].forEach { writer.append($0) }
        writer.startSegment()
        points[2...4].forEach { writer.append($0) }

        #expect(draft().recover()?.segments == [Array(points[0...1]), Array(points[2...4])])
    }

    @Test func ignoresAnEmptySegmentMarker() {
        let writer = draft()
        writer.start(at: Fixtures.start)
        writer.startSegment()
        points.forEach { writer.append($0) }

        #expect(draft().recover()?.segments == [points])
    }

    @Test func recoversWhenTheLastLineWasCutOffMidWrite() throws {
        let writer = draft()
        writer.start(at: Fixtures.start)
        points.forEach { writer.append($0) }

        // Simulate the app dying part-way through writing a point.
        let data = try Data(contentsOf: url)
        try (data + Data(#"{"point":{"lat":50.1,"lo"#.utf8)).write(to: url)

        #expect(draft().recover()?.segments == [points])
    }

    @Test func startingAgainReplacesTheOldDraft() {
        let first = draft()
        first.start(at: Fixtures.start)
        points.forEach { first.append($0) }

        let second = draft()
        second.start(at: Fixtures.start.addingTimeInterval(3600))
        second.append(points[0])

        let recovered = draft().recover()
        #expect(recovered?.startedAt == Fixtures.start.addingTimeInterval(3600))
        #expect(recovered?.segments == [[points[0]]])
    }

    @Test func discardLeavesNothingBehind() {
        let writer = draft()
        writer.start(at: Fixtures.start)
        points.forEach { writer.append($0) }
        writer.discard()

        #expect(draft().recover() == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func aDraftWithoutPointsIsNotWorthRecovering() {
        let writer = draft()
        writer.start(at: Fixtures.start)

        #expect(draft().recover() == nil)
    }
}
