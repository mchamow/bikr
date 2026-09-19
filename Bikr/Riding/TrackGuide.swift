import BikrCore
import CoreLocation
import Observation

/// Guides the rider along a chosen track and warns when they leave it.
@Observable
final class TrackGuide {
    /// The rider's earlier self on this track, and how the race is going.
    struct Ghost {
        var position: TrackPoint
        /// Seconds the rider is ahead (positive) or behind (negative).
        var lead: TimeInterval
        var hasFinished: Bool
    }

    private(set) var track: Track?
    private(set) var status: FollowStatus?
    private(set) var ghost: Ghost?
    /// Where the rider was at the last update.
    private(set) var position: TrackPoint?

    @ObservationIgnored private var follower: TrackFollower?
    @ObservationIgnored private var ghostRun: Track?
    @ObservationIgnored private var ghostRider: GhostRider?
    @ObservationIgnored private var raceStartedAt: Date?

    /// Called when the rider leaves the track, comes back to it, or reaches the
    /// end. What to do about it is the app's decision, not the guide's.
    @ObservationIgnored var onStray: ((FollowStatus) -> Void)?
    @ObservationIgnored var onRejoin: (() -> Void)?
    @ObservationIgnored var onFinish: ((Track) -> Void)?

    var isActive: Bool { track != nil }

    /// - Parameter ghostRun: the earlier ride to race along this track. The
    ///   track's own recording when there is nothing quicker.
    func follow(_ track: Track, racing ghostRun: Track? = nil) {
        guard let follower = TrackFollower(segments: track.segments) else { return }
        self.track = track
        self.ghostRun = ghostRun ?? track
        self.follower = follower
        status = nil
        position = nil
        GuideAlerts.prepare()
    }

    func stop() {
        track = nil
        follower = nil
        status = nil
        position = nil
        ghost = nil
        ghostRun = nil
        ghostRider = nil
        raceStartedAt = nil
    }

    /// Sets the rider's old self going from wherever they joined the track,
    /// and keeps score. Turning round starts the race again from there.
    private func race(_ status: FollowStatus, at now: Date) {
        guard let track, let ghostRun else { return }
        if ghostRider == nil || ghostRider?.direction != status.direction {
            ghostRider = GhostRider(
                run: ghostRun.segments,
                on: track.segments,
                joinedAtAlong: status.alongTrack,
                direction: status.direction
            )
            raceStartedAt = now
        }
        guard let ghostRider, let raceStartedAt else {
            ghost = nil
            return
        }
        let elapsed = now.timeIntervalSince(raceStartedAt)
        ghost = Ghost(
            position: ghostRider.position(after: elapsed),
            lead: ghostRider.lead(at: status.alongTrack, after: elapsed),
            hasFinished: ghostRider.hasFinished(after: elapsed)
        )
    }

    func update(_ location: CLLocation) {
        guard var follower, let track,
              location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 50 else { return }
        let here = TrackPoint(location)
        let new = follower.update(with: here)
        self.follower = follower
        let old = status
        status = new
        position = here
        race(new, at: location.timestamp)

        // Nothing to report on the first fix: the banner already says where
        // the rider is.
        guard let old else { return }
        if new.isOffTrack && !old.isOffTrack {
            onStray?(new)
        } else if !new.isOffTrack && old.isOffTrack {
            onRejoin?()
        }
        if new.isFinished && !old.isFinished {
            onFinish?(track)
        }
    }
}
