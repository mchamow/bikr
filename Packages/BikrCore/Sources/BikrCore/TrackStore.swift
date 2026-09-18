import Foundation

/// Saves tracks as JSON files in one directory: `<id>.json` holds the points,
/// `index.json` holds the summaries so the list loads without reading every
/// ride. If the index is missing or unreadable it is rebuilt from the files.
public struct TrackStore: Sendable {
    public let directory: URL

    public init(directory: URL) {
        self.directory = directory
    }

    private var indexURL: URL { directory.appending(path: "index.json") }

    private func url(for id: UUID) -> URL {
        directory.appending(path: "\(id.uuidString).json")
    }

    /// Newest first.
    public func summaries() throws -> [TrackSummary] {
        let summaries: [TrackSummary]
        if let data = try? Data(contentsOf: indexURL),
           let index = try? JSONDecoder().decode([TrackSummary].self, from: data) {
            summaries = index
        } else {
            summaries = try rebuildIndex()
        }
        return summaries.sorted { $0.createdAt > $1.createdAt }
    }

    public func track(id: UUID) throws -> Track {
        try JSONDecoder().decode(Track.self, from: Data(contentsOf: url(for: id)))
    }

    /// Creates or replaces the track and returns its fresh summary.
    @discardableResult
    public func save(_ track: Track) throws -> TrackSummary {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(track).write(to: url(for: track.id), options: .atomic)
        let summary = track.summary
        var index = try summaries().filter { $0.id != track.id }
        index.append(summary)
        try writeIndex(index)
        return summary
    }

    public func rename(id: UUID, to name: String) throws {
        var track = try track(id: id)
        track.name = name
        try save(track)
    }

    public func delete(id: UUID) throws {
        let file = url(for: id)
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }
        try writeIndex(summaries().filter { $0.id != id })
    }

    private func writeIndex(_ index: [TrackSummary]) throws {
        try JSONEncoder().encode(index).write(to: indexURL, options: .atomic)
    }

    private func rebuildIndex() throws -> [TrackSummary] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        let index = files
            .filter { $0.pathExtension == "json" && UUID(uuidString: $0.deletingPathExtension().lastPathComponent) != nil }
            .compactMap { try? JSONDecoder().decode(Track.self, from: Data(contentsOf: $0)).summary }
        try writeIndex(index)
        return index
    }
}
