import BikrCore
import CoreLocation
import Observation

/// Guides the rider along a chosen track and warns when they leave it.
@Observable
final class TrackGuide {
    private(set) var track: Track?
    private(set) var status: FollowStatus?
    /// Where the rider was at the last update.
    private(set) var position: TrackPoint?

    @ObservationIgnored private var follower: TrackFollower?

    var isActive: Bool { track != nil }

    func follow(_ track: Track) {
        guard let follower = TrackFollower(segments: track.segments) else { return }
        self.track = track
        self.follower = follower
        status = nil
        position = nil
        GuideAlerts.requestPermission()
    }

    func stop() {
        track = nil
        follower = nil
        status = nil
        position = nil
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

        // No alerts on the first fix: the banner already says where you are.
        guard let old else { return }
        if new.isOffTrack && !old.isOffTrack {
            GuideAlerts.offTrack(by: new.distanceFromTrack)
        } else if !new.isOffTrack && old.isOffTrack {
            GuideAlerts.backOnTrack()
        }
        if new.isFinished && !old.isFinished {
            GuideAlerts.finished(track.name)
        }
    }
}
