import Foundation

/// A ride that was being recorded when the app stopped.
public struct RecoveredRide: Equatable, Sendable {
    public var startedAt: Date
    public var segments: [[TrackPoint]]

    public var stats: TrackStats { TrackStats(segments: segments) }
}

/// Writes the ride being recorded to disk point by point, so a ride is not
/// lost when iOS shuts the app down or it crashes mid-ride.
///
/// The file holds one JSON record per line and is only ever appended to, which
/// keeps each write small. A line left half-written by a crash is skipped when
/// reading, costing at most the last GPS fix.
public final class RideDraft {
    public let url: URL
    private var handle: FileHandle?

    public init(url: URL) {
        self.url = url
    }

    deinit {
        try? handle?.close()
    }

    /// Begins a draft, replacing any existing one.
    public func start(at date: Date) {
        try? handle?.close()
        handle = nil
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        FileManager.default.createFile(atPath: url.path, contents: nil)
        handle = try? FileHandle(forWritingTo: url)
        write(Record(started: date))
    }

    public func append(_ point: TrackPoint) {
        write(Record(point: point))
    }

    /// Marks the start of a new segment, i.e. the ride was resumed after a pause.
    public func startSegment() {
        write(Record(segment: true))
    }

    public func discard() {
        try? handle?.close()
        handle = nil
        try? FileManager.default.removeItem(at: url)
    }

    /// What was recorded before the app stopped, or nil when there is nothing
    /// worth recovering.
    public func recover() -> RecoveredRide? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        let decoder = JSONDecoder()
        var startedAt: Date?
        var segments: [[TrackPoint]] = [[]]

        for line in data.split(separator: UInt8(ascii: "\n")) {
            guard let record = try? decoder.decode(Record.self, from: Data(line)) else { continue }
            if let started = record.started {
                startedAt = started
            }
            if record.segment == true, segments[segments.count - 1].isEmpty == false {
                segments.append([])
            }
            if let point = record.point {
                segments[segments.count - 1].append(point)
            }
        }

        let recorded = segments.filter { !$0.isEmpty }
        guard let first = recorded.first?.first else { return nil }
        return RecoveredRide(startedAt: startedAt ?? first.timestamp ?? .now, segments: recorded)
    }

    private func write(_ record: Record) {
        guard let handle, var line = try? JSONEncoder().encode(record) else { return }
        line.append(UInt8(ascii: "\n"))
        try? handle.write(contentsOf: line)
    }

    /// One line of the file. Exactly one property is set.
    private struct Record: Codable {
        var started: Date?
        var segment: Bool?
        var point: TrackPoint?
    }
}
