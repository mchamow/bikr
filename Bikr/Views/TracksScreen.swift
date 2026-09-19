import BikrCore
import SwiftUI

/// Ride history and imported GPX tracks.
struct TracksScreen: View {
    @Environment(AppModel.self) private var model
    @State private var isImporting = false

    var body: some View {
        @Bindable var model = model
        NavigationStack(path: $model.tracksPath) {
            List {
                TrackSections(
                    recorded: model.recordedTracks,
                    imported: model.importedTracks,
                    onDelete: model.delete(trackIDs:)
                ) { summary in
                    NavigationLink(value: summary.id) {
                        TrackRow(summary: summary, record: model.record(of: summary.id))
                    }
                }
            }
            .overlay {
                if model.summaries.isEmpty {
                    ContentUnavailableView {
                        Label("No Tracks Yet", systemImage: "bicycle")
                    } description: {
                        Text("Your recorded rides show up here. You can also import GPX files to follow.")
                    } actions: {
                        Button("Import GPX") { isImporting = true }
                            .buttonStyle(.glassProminent)
                    }
                }
            }
            .navigationTitle("Tracks")
            .navigationDestination(for: UUID.self) { id in
                TrackDetailScreen(trackID: id)
            }
            .toolbar {
                Button("Import GPX", systemImage: "square.and.arrow.down") {
                    isImporting = true
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.gpx], allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    model.importGPX(from: urls)
                case .failure(let error):
                    model.message = error.localizedDescription
                }
            }
        }
    }
}
