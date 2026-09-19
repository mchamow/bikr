import Foundation
import Network
import Observation

/// Whether the phone can reach the network, which decides if Apple's map tiles
/// can load. Bikr works either way; the map is the only thing that needs it.
@Observable
final class NetworkMonitor {
    private(set) var isOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()

    init() {
        // Lets the UI tests (and a curious rider) see the offline behaviour
        // without turning on airplane mode.
        if TestSettings.forcesOffline {
            isOnline = false
            return
        }
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "dev.bikr.network"))
    }

    deinit {
        monitor.cancel()
    }
}
