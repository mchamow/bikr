import BikrCore
import CoreTransferable
import UniformTypeIdentifiers

extension UTType {
    /// Declared under UTImportedTypeDeclarations in Info.plist.
    nonisolated static let gpx = UTType(importedAs: "com.topografix.gpx", conformingTo: .xml)
}

/// Shares a track as a `.gpx` file named after it.
nonisolated struct GPXExport: Transferable {
    let track: Track

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .gpx) { export in
            let folder = URL.temporaryDirectory.appending(path: export.track.id.uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let file = folder.appending(path: "\(export.fileName).gpx")
            try GPX.data(for: export.track).write(to: file, options: .atomic)
            return SentTransferredFile(file)
        }
    }

    private var fileName: String {
        let unsafe = CharacterSet(charactersIn: "/\\:?%*|\"<>")
        let name = track.name.components(separatedBy: unsafe).joined(separator: "-")
        return name.isEmpty ? "Track" : name
    }
}
