import BikrCore
import MapKit
import SwiftUI

/// A labeled number, e.g. "DISTANCE 12.3 km".
struct StatView: View {
    let title: LocalizedStringKey
    let value: String
    var isLarge = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
            Text(value)
                .font(.system(isLarge ? .largeTitle : .title2, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// All stats of a finished track. Time-based ones are hidden for tracks
/// without timestamps, which is common for planned routes.
struct TrackStatsGrid: View {
    let stats: TrackStats

    var body: some View {
        Grid(horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                StatView(title: "Distance", value: Format.distance(stats.distance))
                StatView(title: "Climb", value: Format.elevation(stats.elevationGain))
            }
            if stats.movingTime > 0 {
                GridRow {
                    StatView(title: "Moving time", value: Format.duration(stats.movingTime))
                    StatView(title: "Total time", value: Format.duration(stats.elapsedTime))
                }
                GridRow {
                    StatView(title: "Avg speed", value: Format.speed(stats.averageSpeed))
                    StatView(title: "Max speed", value: Format.speed(stats.maxSpeed))
                }
            }
        }
    }
}

struct TrackRow: View {
    let summary: TrackSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summary.name)
                .font(.headline)
            HStack(spacing: 6) {
                Text(summary.createdAt, format: .dateTime.day().month().year())
                Text("·")
                Text(Format.distance(summary.stats.distance))
                if summary.stats.movingTime > 0 {
                    Text("·")
                    Text(Format.duration(summary.stats.movingTime))
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }
}

/// Recorded and imported tracks in two sections.
struct TrackSections<Row: View>: View {
    let recorded: [TrackSummary]
    let imported: [TrackSummary]
    var onDelete: (([UUID]) -> Void)?
    @ViewBuilder let row: (TrackSummary) -> Row

    var body: some View {
        section("My rides", recorded)
        section("Imported", imported)
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, _ items: [TrackSummary]) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { row($0) }
                    .onDelete(perform: onDelete.map { delete in
                        { offsets in delete(offsets.map { items[$0].id }) }
                    })
            }
        }
    }
}

/// Lines for a track's segments, orange for rides and blue for routes to follow.
struct TrackLines: MapContent {
    let segments: [[TrackPoint]]
    var color: Color
    var width: CGFloat = 5

    var body: some MapContent {
        ForEach(segments.indices, id: \.self) { index in
            MapPolyline(coordinates: segments[index].map(\.coordinate))
                .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
    }
}

extension TrackOrigin {
    var color: Color {
        switch self {
        case .recorded: .orange
        case .imported: .blue
        }
    }
}
