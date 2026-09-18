import CoreLocation
import Observation

/// Streams GPS fixes while a ride is recorded or a track followed, and keeps
/// the app running in the background meanwhile.
@Observable
final class LocationFeed {
    enum Problem {
        case denied
        case approximateOnly
        case unavailable
    }

    private(set) var isRunning = false
    private(set) var problem: Problem?

    @ObservationIgnored var onLocation: (CLLocation) -> Void = { _ in }

    @ObservationIgnored private var updates: Task<Void, Never>?
    @ObservationIgnored private var serviceSession: CLServiceSession?
    @ObservationIgnored private var backgroundSession: CLBackgroundActivitySession?

    /// - Parameter inBackground: keep running with the screen locked. Only for
    ///   an actual ride; merely looking at the map doesn't need it.
    func start(inBackground: Bool) {
        if isRunning {
            keepRunningInBackground(inBackground)
            return
        }
        isRunning = true
        // Asks for "While Using" permission and precise location if needed.
        serviceSession = CLServiceSession(authorization: .whenInUse, fullAccuracyPurposeKey: "RideTracking")
        keepRunningInBackground(inBackground)
        updates = Task { [weak self] in
            do {
                for try await update in CLLocationUpdate.liveUpdates(.fitness) {
                    self?.handle(update)
                }
            } catch {
                self?.problem = .unavailable
            }
        }
    }

    /// Holding a background activity session is what lets a ride keep recording
    /// with the screen locked; it must be started in the foreground.
    private func keepRunningInBackground(_ wanted: Bool) {
        switch (wanted, backgroundSession) {
        case (true, nil):
            backgroundSession = CLBackgroundActivitySession()
        case (false, .some(let session)):
            session.invalidate()
            backgroundSession = nil
        default:
            break
        }
    }

    func stop() {
        guard isRunning else { return }
        updates?.cancel()
        updates = nil
        backgroundSession?.invalidate()
        backgroundSession = nil
        serviceSession?.invalidate()
        serviceSession = nil
        isRunning = false
        problem = nil
    }

    private func handle(_ update: CLLocationUpdate) {
        if update.authorizationDenied || update.authorizationDeniedGlobally {
            problem = .denied
        } else if update.accuracyLimited {
            problem = .approximateOnly
        } else if let location = update.location {
            problem = nil
            onLocation(location)
        }
    }
}
