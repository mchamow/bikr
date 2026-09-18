import BikrCore
import MapKit
import SwiftUI

/// The screen you ride with: record, pause, finish, and follow a track.
/// Everything here works without a connection; Apple's map is the extra when
/// there is one.
struct RideScreen: View {
    @Environment(AppModel.self) private var model
    @AppStorage("showsAppleMap") private var showsAppleMap = true
    @State private var camera = MapCameraPosition.userLocation(fallback: .automatic)
    @State private var isPickingTrack = false
    @State private var isConfirmingFinish = false

    private var recorder: RideRecorder { model.recorder }
    private var guide: TrackGuide { model.guide }
    private var usesAppleMap: Bool { showsAppleMap && model.network.isOnline }

    var body: some View {
        Group {
            if usesAppleMap {
                appleMap
            } else {
                drawnMap
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                if !model.network.isOnline {
                    NoticeBanner(
                        icon: "wifi.slash",
                        tint: .secondary,
                        text: "No connection. Bikr keeps recording and guiding; only the map is missing."
                    )
                }
                if let problem = model.location.problem {
                    LocationProblemBanner(problem: problem)
                }
                if let track = guide.track {
                    GuidanceBanner(
                        track: track,
                        status: guide.status,
                        bearingToTrack: bearingToTrack,
                        strayedBy: model.strayedBy,
                        onStop: model.stopFollowing,
                        onBackToTrack: model.keepFollowingTheTrack,
                        onNewRoute: model.trackNewRoute
                    )
                }
            }
            .padding(.horizontal)
        }
        .safeAreaInset(edge: .bottom) {
            controls
                .padding(.horizontal)
                .padding(.bottom, 8)
        }
        .sheet(isPresented: $isPickingTrack) {
            TrackPickerSheet()
        }
        .confirmationDialog("Finish this ride?", isPresented: $isConfirmingFinish, titleVisibility: .visible) {
            Button("Save Ride") { model.finishRide(save: true) }
            Button("Discard Ride", role: .destructive) { model.finishRide(save: false) }
        }
        .onChange(of: guide.track?.id) {
            // Show the whole track when following starts; the location button
            // brings the camera back to the rider.
            if let track = guide.track {
                withAnimation { camera = .rect(track.mapRect) }
            }
        }
        .onAppear { model.isRideScreenVisible = true }
        .onDisappear { model.isRideScreenVisible = false }
    }

    private var appleMap: some View {
        Map(position: $camera) {
            if let track = guide.track {
                TrackLines(segments: track.segments, color: .blue.opacity(0.7), width: 7)
            }
            if let status = guide.status, status.isOffTrack, let here = guide.position {
                MapPolyline(coordinates: [here.coordinate, status.closestPoint.coordinate])
                    .stroke(.red, style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 8]))
            }
            TrackLines(segments: recorder.segments, color: .orange)
            UserAnnotation()
        }
        .mapControls {
            MapUserLocationButton()
            MapCompass()
            MapScaleView()
        }
    }

    private var drawnMap: some View {
        InteractiveTrackCanvas(
            lines: canvasLines,
            rider: canvasRider,
            wayBack: canvasWayBack,
            followsRider: true
        )
        .overlay {
            if canvasRider == nil && canvasLines.allSatisfy({ $0.segments.allSatisfy(\.isEmpty) }) {
                ContentUnavailableView("Waiting for GPS…", systemImage: "location.magnifyingglass",
                                       description: Text("Your position and track appear here, with or without a connection."))
            }
        }
        .ignoresSafeArea()
    }

    // MARK: What to draw without a map

    private var canvasLines: [TrackCanvas.Line] {
        var lines: [TrackCanvas.Line] = []
        if let track = guide.track {
            lines.append(TrackCanvas.Line(segments: track.segments, color: .blue.opacity(0.8), width: 6))
        }
        lines.append(TrackCanvas.Line(segments: recorder.segments, color: .orange, width: 4))
        return lines
    }

    private var riderPoint: TrackPoint? {
        model.currentFix.map(TrackPoint.init)
    }

    private var canvasRider: TrackCanvas.Rider? {
        guard let fix = model.currentFix else { return nil }
        let course = fix.course >= 0 && fix.courseAccuracy >= 0 ? fix.course : nil
        return TrackCanvas.Rider(position: TrackPoint(fix), course: course)
    }

    private var canvasWayBack: (from: TrackPoint, to: TrackPoint)? {
        guard let status = guide.status, status.isOffTrack, let riderPoint else { return nil }
        return (from: riderPoint, to: status.closestPoint)
    }

    /// Which way the track lies, for the arrow in the guidance banner.
    private var bearingToTrack: Double? {
        guard let status = guide.status, status.isOffTrack else { return nil }
        let from = riderPoint ?? guide.position
        return from?.bearing(to: status.closestPoint)
    }

    // MARK: Controls

    private var controls: some View {
        VStack(spacing: 12) {
            if recorder.state != .idle {
                LiveStats(recorder: recorder)
            }
            HStack(spacing: 12) {
                if !guide.isActive {
                    Button("Follow a Track", systemImage: "point.bottomleft.forward.to.point.topright.scurvepath") {
                        isPickingTrack = true
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                }
                if model.network.isOnline {
                    Button(showsAppleMap ? "Hide Map" : "Show Map", systemImage: showsAppleMap ? "map.fill" : "map") {
                        showsAppleMap.toggle()
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                }
                switch recorder.state {
                case .idle:
                    wideButton("Start Ride", systemImage: "record.circle", tint: .orange) {
                        model.startRide()
                        withAnimation { camera = .userLocation(fallback: .automatic) }
                    }
                case .recording:
                    wideButton("Pause", systemImage: "pause.fill", tint: nil, action: model.pauseRide)
                    wideButton("Finish", systemImage: "stop.fill", tint: .red) { isConfirmingFinish = true }
                case .paused:
                    wideButton("Resume", systemImage: "play.fill", tint: .orange, action: model.resumeRide)
                    wideButton("Finish", systemImage: "stop.fill", tint: .red) { isConfirmingFinish = true }
                }
            }
            .controlSize(.extraLarge)
        }
    }

    @ViewBuilder
    private func wideButton(_ title: LocalizedStringKey, systemImage: String, tint: Color?, action: @escaping () -> Void) -> some View {
        let button = Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        if let tint {
            button.buttonStyle(.glassProminent).tint(tint)
        } else {
            button.buttonStyle(.glass)
        }
    }
}

private struct LiveStats: View {
    let recorder: RideRecorder

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            Grid(horizontalSpacing: 16, verticalSpacing: 12) {
                GridRow {
                    StatView(title: recorder.state == .paused ? "Paused" : "Time",
                             value: Format.duration(recorder.activeDuration(at: context.date)), isLarge: true)
                    StatView(title: "Distance", value: Format.distance(recorder.stats.distance), isLarge: true)
                }
                GridRow {
                    StatView(title: "Speed", value: recorder.currentSpeed.map(Format.speed) ?? "–")
                    StatView(title: "Avg speed", value: Format.speed(recorder.stats.averageSpeed))
                }
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 28))
    }
}

private struct GuidanceBanner: View {
    let track: Track
    let status: FollowStatus?
    /// Degrees from north towards the track, when off it.
    let bearingToTrack: Double?
    /// Set while Bikr is asking whether leaving the track was deliberate.
    let strayedBy: Double?
    let onStop: () -> Void
    let onBackToTrack: () -> Void
    let onNewRoute: () -> Void

    var body: some View {
        let isOffTrack = status?.isOffTrack == true
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                if isOffTrack, let bearingToTrack {
                    // Points the way back to the track, relative to north.
                    Image(systemName: "arrow.up")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.red)
                        .rotationEffect(.degrees(bearingToTrack))
                } else {
                    Image(systemName: isOffTrack ? "exclamationmark.triangle.fill" : "point.bottomleft.forward.to.point.topright.scurvepath")
                        .font(.title2)
                        .foregroundStyle(isOffTrack ? .red : .blue)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(.headline)
                        .lineLimit(1)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(isOffTrack ? .red : .secondary)
                        .monospacedDigit()
                }
                Spacer()
                Button("Stop Following", systemImage: "xmark", action: onStop)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
            }

            // Leaving the track is often deliberate, so ask rather than nag.
            if strayedBy != nil {
                HStack(spacing: 10) {
                    Button("Back to Track", action: onBackToTrack)
                        .buttonStyle(.glassProminent)
                        .tint(.blue)
                    Button("Track New Route", action: onNewRoute)
                        .buttonStyle(.glass)
                }
                .font(.subheadline.weight(.semibold))
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 24))
    }

    private var detail: String {
        guard let status else { return String(localized: "Waiting for GPS…") }
        if status.isOffTrack {
            return String(localized: "Off track · \(Format.distance(status.distanceFromTrack)) back to it")
        }
        if status.isFinished {
            return String(localized: "You've reached the end")
        }
        return String(localized: "\(Format.distance(status.distanceRemaining)) to go · \(Format.distance(status.distanceCovered)) done")
    }
}

private struct NoticeBanner: View {
    let icon: String
    let tint: Color
    let text: LocalizedStringKey

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(text)
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 24))
        .accessibilityIdentifier("offlineBanner")
    }
}

private struct LocationProblemBanner: View {
    let problem: LocationFeed.Problem
    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
            Spacer()
            if problem != .unavailable {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.glass)
            }
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 24))
    }

    private var message: LocalizedStringKey {
        switch problem {
        case .denied: "Bikr needs location access to record and guide rides."
        case .approximateOnly: "Turn on Precise Location for accurate tracks."
        case .unavailable: "GPS isn't available right now."
        }
    }
}

private struct TrackPickerSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                TrackSections(recorded: model.recordedTracks, imported: model.importedTracks) { summary in
                    Button {
                        model.follow(trackID: summary.id)
                        dismiss()
                    } label: {
                        TrackRow(summary: summary)
                    }
                    .tint(.primary)
                }
            }
            .overlay {
                if model.summaries.isEmpty {
                    ContentUnavailableView(
                        "No Tracks Yet",
                        systemImage: "point.bottomleft.forward.to.point.topright.scurvepath",
                        description: Text("Record a ride, or import a GPX file in the Tracks tab.")
                    )
                }
            }
            .navigationTitle("Follow a Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
