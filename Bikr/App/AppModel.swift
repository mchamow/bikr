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
    /// A ride the app was recording when it last stopped, waiting to be saved
    /// or dropped.
    private(set) var recoveredRide: RecoveredRide?

    let recorder: RideRecorder
    let guide = TrackGuide()
    let location = LocationFeed()

    @ObservationIgnored private let store: TrackStore
    @ObservationIgnored private let draft: RideDraft

    init(store: TrackStore = .standard, draft: RideDraft = .standard) {
        self.store = store
        self.draft = draft
        self.recorder = RideRecorder(draft: draft)
        self.recoveredRide = draft.recover()
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
        // Recording would overwrite a draft that hasn't been dealt with, so
        // keep that ride rather than lose it.
        storeRecoveredRide()
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
        guard save else {
            draft.discard()
            return
        }
        guard !segments.isEmpty else {
            draft.discard()
            message = "Nothing to save: no GPS position was recorded during this ride."
            return
        }
        let track = Track(name: Self.rideName(startedAt: startedAt), origin: .recorded, createdAt: startedAt, segments: segments)
        // The draft stays if saving fails, so the ride can be recovered later.
        if perform("save the ride", { try store.save(track) }) {
            draft.discard()
        }
    }

    // MARK: An interrupted ride

    func saveRecoveredRide() {
        if storeRecoveredRide() {
            tab = .tracks
        }
    }

    func discardRecoveredRide() {
        draft.discard()
        recoveredRide = nil
    }

    @discardableResult
    private func storeRecoveredRide() -> Bool {
        guard let recovered = recoveredRide else { return false }
        let track = Track(
            name: Self.rideName(startedAt: recovered.startedAt),
            origin: .recorded,
            createdAt: recovered.startedAt,
            segments: recovered.segments
        )
        guard perform("save the interrupted ride", { try store.save(track) }) else { return false }
        draft.discard()
        recoveredRide = nil
        return true
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

    /// Runs `body`, turning any error into a message for the user. Returns
    /// whether it worked.
    @discardableResult
    private func perform(_ action: String, _ body: () throws -> Void) -> Bool {
        var succeeded = true
        do {
            try body()
        } catch {
            message = "Couldn't \(action): \(error.localizedDescription)"
            succeeded = false
        }
        reloadSummaries()
        return succeeded
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

extension RideDraft {
    static let standard = RideDraft(url: URL.applicationSupportDirectory.appending(path: "ride-in-progress.jsonl"))
}
