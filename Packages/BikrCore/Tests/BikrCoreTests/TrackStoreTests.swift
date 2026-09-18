import Foundation
import Testing
@testable import BikrCore

struct TrackStoreTests {
    let store = TrackStore(directory: FileManager.default.temporaryDirectory.appending(path: "BikrCoreTests-\(UUID())"))

    func ride(_ name: String, daysAgo: Double) -> Track {
        Track(name: name, origin: .recorded, createdAt: Fixtures.start.addingTimeInterval(-daysAgo * 86_400),
              segments: [Fixtures.northbound(count: 11)])
    }

    @Test func emptyStoreHasNoTracks() throws {
        #expect(try store.summaries().isEmpty)
    }

    @Test func savesLoadsAndListsNewestFirst() throws {
        let old = ride("Old", daysAgo: 2), new = ride("New", daysAgo: 1)
        try store.save(old)
        let summary = try store.save(new)

        #expect(abs(summary.stats.distance - 100) < 0.5)
        #expect(try store.summaries().map(\.name) == ["New", "Old"])
        #expect(try store.track(id: old.id) == old)
    }

    @Test func renameAndDelete() throws {
        let a = ride("A", daysAgo: 1), b = ride("B", daysAgo: 2)
        try store.save(a)
        try store.save(b)

        try store.rename(id: a.id, to: "Renamed")
        try store.delete(id: b.id)

        #expect(try store.summaries().map(\.name) == ["Renamed"])
        #expect(try store.track(id: a.id).name == "Renamed")
        #expect(throws: (any Error).self) { try store.track(id: b.id) }
    }

    @Test func rebuildsLostIndexFromTrackFiles() throws {
        let track = ride("Survivor", daysAgo: 0)
        try store.save(track)
        try FileManager.default.removeItem(at: store.directory.appending(path: "index.json"))

        #expect(try store.summaries() == [track.summary])
    }
}
