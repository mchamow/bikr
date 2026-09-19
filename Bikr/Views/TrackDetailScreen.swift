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

                    RunsList(runs: model.runs(of: trackID), best: model.bestRun(of: trackID)?.id)
                }
                .padding()
                // Room for the last run to clear the tab bar.
                .padding(.bottom, 60)
            }
        } else if let loadError {
            ContentUnavailableView("Can't Open Track", systemImage: "exclamationmark.triangle", description: Text(loadError))
        } else {
            ProgressView()
        }
    }
}

/// Apple's map when there is a connection, the drawn track when there isn't.
/// Every time this route has been ridden, quickest first to beat marked.
private struct RunsList: View {
    let runs: [TrackSummary]
    let best: UUID?

    var body: some View {
        if !runs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Runs")
                    .font(.headline)
                ForEach(runs) { run in
                    NavigationLink(value: run.id) {
                        HStack(spacing: 10) {
                            if run.id == best {
                                Image(systemName: "star.fill").foregroundStyle(.yellow)
                            }
                            Text(run.createdAt, format: .dateTime.day().month())
                            Spacer()
                            Text(Format.duration(run.stats.movingTime))
                            Text(Format.speed(run.stats.averageSpeed))
                                .foregroundStyle(.secondary)
                        }
                        .monospacedDigit()
                    }
                    .tint(.primary)
                    Divider()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

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
            InteractiveTrackCanvas(
                lines: [TrackCanvas.Line(segments: track.segments, color: track.origin.color)]
            )
        }
    }
}
