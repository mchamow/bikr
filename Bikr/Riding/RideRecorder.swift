import BikrCore
import CoreLocation
import Observation

/// The ride being recorded: start, pause, resume, finish.
@Observable
final class RideRecorder {
    enum State {
        case idle, recording, paused
    }

    private(set) var state = State.idle
    /// A new segment starts after every pause.
    private(set) var segments: [[TrackPoint]] = []
    private(set) var stats = TrackStats.zero
    /// m/s from the latest fix, nil when unknown or paused.
    private(set) var currentSpeed: Double?
    private(set) var startedAt: Date?

    @ObservationIgnored private var accumulator = StatsAccumulator()
    @ObservationIgnored private var filter = LocationFilter()
    @ObservationIgnored private var speedEstimator = SpeedEstimator()
    /// Mirrors the ride to disk so it survives the app being shut down.
    @ObservationIgnored private let draft: RideDraft?

    init(draft: RideDraft? = nil) {
        self.draft = draft
    }
    /// Recording time before the current stretch (i.e. up to the last pause).
    private var activeTimeBeforeStretch: TimeInterval = 0
    private var stretchStartedAt: Date?

    /// Time spent recording, pauses excluded.
    func activeDuration(at now: Date) -> TimeInterval {
        activeTimeBeforeStretch + (stretchStartedAt.map { now.timeIntervalSince($0) } ?? 0)
    }

    func start(at now: Date = .now) {
        guard state == .idle else { return }
        reset()
        segments = [[]]
        startedAt = now
        stretchStartedAt = now
        state = .recording
        draft?.start(at: now)
    }

    func pause(at now: Date = .now) {
        guard state == .recording else { return }
        activeTimeBeforeStretch = activeDuration(at: now)
        stretchStartedAt = nil
        currentSpeed = nil
        state = .paused
    }

    func resume(at now: Date = .now) {
        guard state == .paused else { return }
        if segments.last?.isEmpty == false {
            segments.append([])
        }
        accumulator.startSegment()
        filter.reset()
        speedEstimator.reset()
        draft?.startSegment()
        stretchStartedAt = now
        state = .recording
    }

    /// Ends the ride and returns what was recorded (empty if no GPS fix made
    /// it). The draft on disk stays until the ride has been saved or dropped.
    func finish() -> [[TrackPoint]] {
        let recorded = segments.filter { !$0.isEmpty }
        reset()
        return recorded
    }

    func record(_ location: CLLocation) {
        guard state == .recording else { return }
        let point = TrackPoint(location)
        if location.horizontalAccuracy >= 0, location.horizontalAccuracy <= filter.maxHorizontalAccuracy {
            currentSpeed = speedEstimator.speed(at: point)
        }
        guard filter.accept(point, horizontalAccuracy: location.horizontalAccuracy) else { return }
        segments[segments.count - 1].append(point)
        draft?.append(point)
        accumulator.add(point)
        stats = accumulator.stats
    }

    private func reset() {
        state = .idle
        segments = []
        stats = .zero
        currentSpeed = nil
        startedAt = nil
        activeTimeBeforeStretch = 0
        stretchStartedAt = nil
        accumulator = StatsAccumulator()
        filter = LocationFilter()
        speedEstimator.reset()
    }
}
