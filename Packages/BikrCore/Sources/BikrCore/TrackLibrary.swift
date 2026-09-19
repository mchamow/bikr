import Foundation

/// The saved tracks, arranged as routes with the runs ridden on them.
public struct TrackLibrary: Sendable {
    /// A run has to cover this much of the route before its time is a time on
    /// that route at all.
    static let countsAsAWholeRun = 0.8

    public let tracks: [TrackSummary]

    public init(_ tracks: [TrackSummary]) {
        self.tracks = tracks
    }

    /// Tracks that stand on their own: first recordings and imported routes,
    /// but not the runs ridden on them.
    public var routes: [TrackSummary] {
        tracks.filter { $0.runOf == nil }
    }

    /// Every run of a route, newest first.
    public func runs(of route: UUID) -> [TrackSummary] {
        tracks.filter { $0.runOf == route }.sorted { $0.createdAt > $1.createdAt }
    }

    /// The quickest run of a route, ignoring any that only covered part of it.
    /// The route's own recording counts as a run of itself, being the time to
    /// beat until it has been ridden again.
    public func bestRun(of route: UUID) -> TrackSummary? {
        guard let itself = tracks.first(where: { $0.id == route }) else { return nil }
        let whole = ([itself] + runs(of: route)).filter {
            $0.stats.movingTime > 0 && $0.stats.distance >= itself.stats.distance * Self.countsAsAWholeRun
        }
        return whole.min { $0.stats.movingTime < $1.stats.movingTime }
    }

    /// How often a route has been ridden, and the time to beat.
    public func record(of route: UUID) -> (runs: Int, best: TimeInterval?) {
        (runs: runs(of: route).count, best: bestRun(of: route)?.stats.movingTime)
    }
}
