import BikrCore
import MapKit
import SwiftUI

/// One track: map, stats, follow, share as GPX, rename, delete.
struct TrackDetailScreen: View {
    let trackID: UUID

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var track: Track?
    @State private var loadError: String?
    @State private var isRenaming = false
    @State private var newName = ""
    @State private var isConfirmingDelete = false

    private var summary: TrackSummary? {
        model.summaries.first { $0.id == trackID }
    }

    var body: some View {
        content
            .navigationTitle(summary?.name ?? "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let track {
                    ToolbarItem {
                        ShareLink(item: GPXExport(track: track), preview: SharePreview(track.name))
                    }
                }
                ToolbarItem {
                    Menu("More", systemImage: "ellipsis") {
                        Button("Rename", systemImage: "pencil") {
                            newName = summary?.name ?? ""
                            isRenaming = true
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
                }
            }
            .alert("Rename Track", isPresented: $isRenaming) {
                TextField("Name", text: $newName)
                Button("Save") { model.rename(trackID: trackID, to: newName) }
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete this track?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete Track", role: .destructive) {
                    model.delete(trackIDs: [trackID])
                    dismiss()
                }
            }
            // Reloads after a rename so the shared GPX file carries the new name.
            .task(id: summary?.name) {
                do {
                    track = try model.track(id: trackID)
                } catch {
                    loadError = error.localizedDescription
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        if let track, let summary {
            ScrollView {
                VStack(spacing: 20) {
                    TrackPreview(track: track, showsAppleMap: model.network.isOnline)
                        .frame(height: 320)
                        .clipShape(.rect(cornerRadius: 24))
                    TrackStatsGrid(stats: summary.stats)
                    Button {
                        model.follow(trackID: trackID)
                    } label: {
                        Label("Follow This Track", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                }
                .padding()
            }
        } else if let loadError {
            ContentUnavailableView("Can't Open Track", systemImage: "exclamationmark.triangle", description: Text(loadError))
        } else {
            ProgressView()
        }
    }
}

/// Apple's map when there is a connection, the drawn track when there isn't.
private struct TrackPreview: View {
    let track: Track
    let showsAppleMap: Bool

    var body: some View {
        if showsAppleMap {
            Map(initialPosition: .rect(track.mapRect)) {
                TrackLines(segments: track.segments, color: track.origin.color)
                if let start = track.points.first {
                    Marker("Start", systemImage: "flag.fill", coordinate: start.coordinate)
                        .tint(.green)
                }
                if let end = track.points.last {
                    Marker("Finish", systemImage: "flag.checkered", coordinate: end.coordinate)
                        .tint(.red)
                }
            }
        } else {
            TrackCanvas(
                lines: [TrackCanvas.Line(segments: track.segments, color: track.origin.color)],
                focus: .fit
            )
        }
    }
}
