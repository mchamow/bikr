import BikrCore
import Foundation
import Observation
import UIKit

/// App-wide state: the saved tracks, the ride being recorded and the track
/// being followed. GPS runs only while one of those needs it.
@Observable
final class AppModel {
    enum Tab: Hashable {
        case ride, tracks
    }

    var tab = Tab.ride
    var tracksPath: [UUID] = []
    /// Shown to the user in an alert, then cleared.
    var message: String?
    private(set) var summaries: [TrackSummary] = []

    let recorder = RideRecorder()
    let guide = TrackGuide()
    let location = LocationFeed()

    @ObservationIgnored private let store: TrackStore

    init(store: TrackStore = .standard) {
        self.store = store
        location.onLocation = { [recorder, guide] location in
            recorder.record(location)
            guide.update(location)
        }
        reloadSummaries()
    }

    var recordedTracks: [TrackSummary] { summaries.filter { $0.origin == .recorded } }
    var importedTracks: [TrackSummary] { summaries.filter { $0.origin == .imported } }

    // MARK: Riding

    func startRide() {
        recorder.start()
        updateLocationNeeds()
    }

    func pauseRide() {
        recorder.pause()
        updateLocationNeeds()
    }

    func resumeRide() {
        recorder.resume()
        updateLocationNeeds()
    }

    func finishRide(save: Bool) {
        let startedAt = recorder.startedAt ?? .now
        let segments = recorder.finish()
        updateLocationNeeds()
        guard save else { return }
        guard !segments.isEmpty else {
            message = "Nothing to save: no GPS position was recorded during this ride."
            return
        }
        let track = Track(name: Self.rideName(startedAt: startedAt), origin: .recorded, createdAt: startedAt, segments: segments)
        perform("save the ride") { try store.save(track) }
    }

    // MARK: Following

    func follow(trackID: UUID) {
        perform("open the track") {
            guide.follow(try store.track(id: trackID))
            tab = .ride
        }
        updateLocationNeeds()
    }

    func stopFollowing() {
        guide.stop()
        updateLocationNeeds()
    }

    // MARK: Library

    func track(id: UUID) throws -> Track {
        try store.track(id: id)
    }

    func rename(trackID: UUID, to name: String) {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        perform("rename the track") { try store.rename(id: trackID, to: name) }
    }

    func delete(trackIDs: [UUID]) {
        if let followed = guide.track?.id, trackIDs.contains(followed) {
            stopFollowing()
        }
        perform("delete the track") {
            for id in trackIDs { try store.delete(id: id) }
        }
    }

    /// Imports GPX files picked in the app or opened from elsewhere, then
    /// shows the result in the Tracks tab.
    func importGPX(from urls: [URL]) {
        var imported: [TrackSummary] = []
        var failed: [String] = []
        for url in urls {
            let isScoped = url.startAccessingSecurityScopedResource()
            defer { if isScoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let document = try GPX.parse(Data(contentsOf: url))
                let name = document.name ?? url.deletingPathExtension().lastPathComponent
                imported.append(try store.save(Track(name: name, origin: .imported, segments: document.segments)))
            } catch {
                failed.append(url.lastPathComponent)
            }
        }
        reloadSummaries()

        if !imported.isEmpty {
            tab = .tracks
            tracksPath = imported.count == 1 ? [imported[0].id] : []
        }
        if !failed.isEmpty {
            message = "Couldn't import \(failed.formatted()). Make sure it's a GPX file with a track or route."
        }
    }

    // MARK: Helpers

    private func updateLocationNeeds() {
        let needed = recorder.state == .recording || guide.isActive
        if needed {
            location.start()
        } else {
            location.stop()
        }
        // Keep the screen on for a phone mounted on the handlebar.
        UIApplication.shared.isIdleTimerDisabled = recorder.state != .idle || guide.isActive
    }

    private func reloadSummaries() {
        do {
            summaries = try store.summaries()
        } catch {
            message = "Couldn't load your tracks: \(error.localizedDescription)"
        }
    }

    private func perform(_ action: String, _ body: () throws -> Void) {
        do {
            try body()
        } catch {
            message = "Couldn't \(action): \(error.localizedDescription)"
        }
        reloadSummaries()
    }

    static func rideName(startedAt date: Date) -> String {
        switch Calendar.current.component(.hour, from: date) {
        case 5..<12: "Morning ride"
        case 12..<17: "Afternoon ride"
        case 17..<22: "Evening ride"
        default: "Night ride"
        }
    }
}

extension TrackStore {
    static let standard = TrackStore(directory: URL.applicationSupportDirectory.appending(path: "Tracks"))
}
