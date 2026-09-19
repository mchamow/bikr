import BikrCore
import SwiftUI

/// Draws tracks, the rider and the way back to the route with no map behind
/// them, from coordinates Bikr already holds. This is what makes the app work
/// with no connection; Apple's map is the extra when there is one.
struct TrackCanvas: View {
    struct Line {
        var segments: [[TrackPoint]]
        var color: Color
        var width: CGFloat = 4
    }

    struct Rider {
        var position: TrackPoint
        /// Direction of travel in degrees from north, when moving.
        var course: Double?
    }

    enum Focus {
        /// Show everything, with a margin.
        case fit
        /// Centre here, showing this many meters across.
        case center(TrackPoint, metersAcross: Double)
    }

    var lines: [Line]
    var focus: Focus
    var rider: Rider?
    /// Dashed line from the rider back to the nearest point of the track.
    var wayBack: (from: TrackPoint, to: TrackPoint)?
    /// The rider's earlier self, racing them along the track.
    var ghost: TrackPoint?
    /// The bearing that points up the screen; 0 leaves north up.
    var rotation: Double = 0
    /// Where the centre sits vertically, 0...1. Lower shows more of the way ahead.
    var focusY: Double = 0.5

    var body: some View {
        Canvas { context, size in
            guard let projection = projection(for: size) else { return }

            for line in lines {
                for segment in line.segments {
                    context.stroke(
                        path(of: segment, projection),
                        with: .color(line.color),
                        style: StrokeStyle(lineWidth: line.width, lineCap: .round, lineJoin: .round)
                    )
                }
            }

            if let wayBack {
                var path = Path()
                path.move(to: projection.place(wayBack.from))
                path.addLine(to: projection.place(wayBack.to))
                context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 8]))
            }

            if let ghost {
                let at = projection.place(ghost)
                let dot = CGRect(x: at.x - 8, y: at.y - 8, width: 16, height: 16)
                context.fill(Path(ellipseIn: dot), with: .color(.secondary.opacity(0.7)))
                context.stroke(Path(ellipseIn: dot), with: .color(.white), lineWidth: 2)
            }
            if let rider {
                draw(rider, in: &context, projection)
            }
            drawNorthArrow(in: &context, size: size)
            drawScaleBar(in: &context, size: size, metersPerPoint: projection.metersPerPoint)
        }
        .background(Color(.secondarySystemBackground))
    }

    private func projection(for size: CGSize) -> CanvasProjection? {
        guard size.width > 0, size.height > 0 else { return nil }
        switch focus {
        case .center(let point, let metersAcross):
            return CanvasProjection(
                centre: point,
                metersPerPoint: metersAcross / size.width,
                width: size.width,
                height: size.height,
                rotation: rotation,
                focusY: focusY
            )
        case .fit:
            // Seeing everything at once is a job for north up.
            let points = lines.flatMap { $0.segments.flatMap(\.self) } + [rider?.position].compactMap(\.self)
            guard let fitted = Self.cameraFitting(points, in: size) else { return nil }
            return CanvasProjection(
                centre: fitted.center,
                metersPerPoint: fitted.metersAcross / size.width,
                width: size.width,
                height: size.height
            )
        }
    }

    /// Skips points that would land on the same spot, so a long ride doesn't
    /// cost thousands of path segments.
    private func path(of segment: [TrackPoint], _ projection: CanvasProjection) -> Path {
        var path = Path()
        var last: CGPoint?
        for point in segment {
            let next = projection.place(point)
            if let last, abs(next.x - last.x) < 1.5, abs(next.y - last.y) < 1.5 { continue }
            if last == nil { path.move(to: next) } else { path.addLine(to: next) }
            last = next
        }
        return path
    }

    private func draw(_ rider: Rider, in context: inout GraphicsContext, _ projection: CanvasProjection) {
        let center = projection.place(rider.position)
        if let course = rider.course {
            // A triangle pointing the way the rider is travelling. When the
            // drawing is turned to their course, that is straight up.
            var arrow = Path()
            arrow.move(to: CGPoint(x: 0, y: -18))
            arrow.addLine(to: CGPoint(x: 11, y: 12))
            arrow.addLine(to: CGPoint(x: 0, y: 6))
            arrow.addLine(to: CGPoint(x: -11, y: 12))
            arrow.closeSubpath()
            let placed = arrow
                .applying(CGAffineTransform(rotationAngle: (course - rotation) * .pi / 180))
                .applying(CGAffineTransform(translationX: center.x, y: center.y))
            context.fill(placed, with: .color(.accentColor))
            context.stroke(placed, with: .color(.white), lineWidth: 2)
        } else {
            let dot = CGRect(x: center.x - 9, y: center.y - 9, width: 18, height: 18)
            context.fill(Path(ellipseIn: dot), with: .color(.accentColor))
            context.stroke(Path(ellipseIn: dot), with: .color(.white), lineWidth: 3)
        }
    }

    private func drawNorthArrow(in context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width - 34, y: 34)
        var needle = Path()
        needle.move(to: CGPoint(x: 0, y: -16))
        needle.addLine(to: CGPoint(x: 7, y: 8))
        needle.addLine(to: CGPoint(x: -7, y: 8))
        needle.closeSubpath()
        // Turning the drawing moves north off the top of the screen, which is
        // the whole point of having the arrow.
        let placed = needle
            .applying(CGAffineTransform(rotationAngle: -rotation * .pi / 180))
            .applying(CGAffineTransform(translationX: center.x, y: center.y))
        context.fill(placed, with: .color(.secondary))
        context.draw(
            context.resolve(Text("N").font(.caption2.weight(.bold)).foregroundStyle(.secondary)),
            at: CGPoint(x: center.x, y: center.y + 24)
        )
    }

    private func drawScaleBar(in context: inout GraphicsContext, size: CGSize, metersPerPoint: Double) {
        let steps = [10.0, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000]
        let widest = Double(size.width) * 0.35 * metersPerPoint
        let meters = steps.last { $0 <= widest } ?? steps[0]
        let length = meters / metersPerPoint
        let y = size.height - 26
        var bar = Path()
        bar.move(to: CGPoint(x: 20, y: y))
        bar.addLine(to: CGPoint(x: 20 + length, y: y))
        bar.move(to: CGPoint(x: 20, y: y - 5))
        bar.addLine(to: CGPoint(x: 20, y: y + 5))
        bar.move(to: CGPoint(x: 20 + length, y: y - 5))
        bar.addLine(to: CGPoint(x: 20 + length, y: y + 5))
        context.stroke(bar, with: .color(.secondary), lineWidth: 2)
        context.draw(
            context.resolve(Text(Format.distance(meters)).font(.caption2).foregroundStyle(.secondary)),
            at: CGPoint(x: 20 + length / 2, y: y - 14)
        )
    }
}

extension CanvasProjection {
    /// Where a coordinate lands on the drawing.
    func place(_ coordinate: TrackPoint) -> CGPoint {
        let point = self.point(for: coordinate)
        return CGPoint(x: point.x, y: point.y)
    }
}

extension TrackCanvas {
    /// Where to look from, to see all of `points` with a margin around them.
    static func cameraFitting(_ points: [TrackPoint], in size: CGSize) -> (center: TrackPoint, metersAcross: Double)? {
        guard !points.isEmpty, size.width > 0, size.height > 0 else { return nil }
        let latitudes = points.map(\.latitude), longitudes = points.map(\.longitude)
        let middle = TrackPoint(
            latitude: ((latitudes.min() ?? 0) + (latitudes.max() ?? 0)) / 2,
            longitude: ((longitudes.min() ?? 0) + (longitudes.max() ?? 0)) / 2
        )
        let offsets = points.map { middle.offset(to: $0) }
        let east = (offsets.map(\.east).max() ?? 0) - (offsets.map(\.east).min() ?? 0)
        let north = (offsets.map(\.north).max() ?? 0) - (offsets.map(\.north).min() ?? 0)
        let metersPerPoint = max(
            max(east / Double(size.width), north / Double(size.height)) * 1.15,
            50 / Double(size.width)   // a very short track still needs some scale
        )
        return (middle, metersPerPoint * Double(size.width))
    }
}

/// The drawn map, made to behave like a map: drag to move, pinch to zoom, and
/// buttons to come back to yourself or to see the whole track. While it is
/// following the rider it turns the way they are going, as a map in a
/// navigation app does.
struct InteractiveTrackCanvas: View {
    var lines: [TrackCanvas.Line]
    var rider: TrackCanvas.Rider?
    var wayBack: (from: TrackPoint, to: TrackPoint)?
    /// The rider's earlier self, racing them along the track.
    var ghost: TrackPoint?
    /// Keeps the rider in the middle until the map is moved by hand.
    var followsRider = false
    /// The bearing to put at the top of the screen while following the rider.
    /// Nil leaves north up.
    var heading: Double?
    /// Whether the rider is going somewhere, which decides whether the map
    /// takes itself back to the navigation view.
    var isMoving = false
    /// How much to show around the rider before anyone zooms.
    var metersAcrossWhenFollowing = 500.0

    @State private var isFollowingRider: Bool?
    @State private var panCentre: TrackPoint?
    @State private var metersAcross: Double?
    @State private var rotationWhileMovedByHand: Double?
    @State private var centreAtDragStart: TrackPoint?
    @State private var metersAcrossAtPinchStart: Double?
    /// When the rider last moved the map themselves.
    @State private var tookOverAt: Date?

    private var follows: Bool { isFollowingRider ?? followsRider }

    /// Turned to the rider's course while following them; whatever it was
    /// turned to when they took hold of it otherwise.
    private var rotation: Double {
        follows ? (heading ?? 0) : (rotationWhileMovedByHand ?? 0)
    }

    /// Riding, the rider sits below the middle so the way ahead fills the
    /// screen — but above the stats panel that covers the bottom third.
    private var focusY: Double {
        follows && rotation != 0 ? 0.58 : 0.5
    }

    private var everything: [TrackPoint] {
        lines.flatMap { $0.segments.flatMap(\.self) } + [rider?.position].compactMap(\.self)
    }

    var body: some View {
        GeometryReader { proxy in
            let camera = camera(in: proxy.size)
            TrackCanvas(
                lines: lines,
                focus: camera.map { .center($0.centre, metersAcross: $0.metersAcross) } ?? .fit,
                rider: rider,
                wayBack: wayBack,
                ghost: ghost,
                rotation: rotation,
                focusY: focusY
            )
            .animation(.linear(duration: 0.9), value: rotation)
            .contentShape(.rect)
            // Fixes arrive about once a second while riding, which is often
            // enough to notice that the rider has left the map alone.
            .onChange(of: rider?.position) { returnToTheRiderIfLeftAlone() }
            .gesture(drag(from: camera, in: proxy.size))
            .simultaneousGesture(pinch(from: camera))
            .overlay(alignment: .trailing) { controls(in: proxy.size) }
        }
    }

    private func camera(in size: CGSize) -> (centre: TrackPoint, metersAcross: Double)? {
        let fitted = TrackCanvas.cameraFitting(everything, in: size)
        if follows, let rider {
            return (rider.position, metersAcross ?? metersAcrossWhenFollowing)
        }
        let span = metersAcross ?? fitted?.metersAcross ?? metersAcrossWhenFollowing
        if let panCentre {
            return (panCentre, span)
        }
        return fitted.map { ($0.center, span) }
    }

    private func drag(from camera: (centre: TrackPoint, metersAcross: Double)?, in size: CGSize) -> some Gesture {
        DragGesture()
            .onChanged { value in
                guard let camera, size.width > 0 else { return }
                let start = centreAtDragStart ?? camera.centre
                if centreAtDragStart == nil {
                    centreAtDragStart = start
                    // Keep whatever way it was turned, rather than snapping
                    // north up under the rider's finger.
                    rotationWhileMovedByHand = rotation
                }
                let projection = CanvasProjection(
                    centre: start,
                    metersPerPoint: camera.metersAcross / Double(size.width),
                    width: Double(size.width),
                    height: Double(size.height),
                    rotation: rotationWhileMovedByHand ?? 0
                )
                isFollowingRider = false
                tookOverAt = .now
                metersAcross = camera.metersAcross
                panCentre = projection.coordinate(
                    movedBy: -Double(value.translation.width),
                    -Double(value.translation.height)
                )
            }
            .onEnded { _ in centreAtDragStart = nil }
    }

    private func pinch(from camera: (centre: TrackPoint, metersAcross: Double)?) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard let camera else { return }
                let base = metersAcrossAtPinchStart ?? camera.metersAcross
                if metersAcrossAtPinchStart == nil {
                    metersAcrossAtPinchStart = base
                    // Zooming out is for looking around, which is done on a
                    // north-up map that stays put.
                    panCentre = camera.centre
                    rotationWhileMovedByHand = 0
                    isFollowingRider = false
                }
                tookOverAt = .now
                metersAcross = min(max(base / value.magnification, 50), 50_000)
            }
            .onEnded { _ in metersAcrossAtPinchStart = nil }
    }

    /// Back to riding: the map returns to following the rider once they have
    /// left it alone for a while and are going somewhere again.
    private func returnToTheRiderIfLeftAlone() {
        guard let tookOverAt, isMoving, rider != nil else { return }
        guard Date.now.timeIntervalSince(tookOverAt) >= AppModel.returnToNavigation else { return }
        withAnimation {
            self.tookOverAt = nil
            isFollowingRider = true
            panCentre = nil
            rotationWhileMovedByHand = nil
            metersAcross = nil
        }
    }

    @ViewBuilder
    private func controls(in size: CGSize) -> some View {
        VStack(spacing: 10) {
            if rider != nil, !follows {
                Button("Centre on Me", systemImage: "location") {
                    withAnimation {
                        tookOverAt = nil
                        isFollowingRider = true
                        panCentre = nil
                        rotationWhileMovedByHand = nil
                        metersAcross = metersAcross ?? metersAcrossWhenFollowing
                    }
                }
            }
            if everything.count > 1 {
                Button("Show the Whole Track", systemImage: "arrow.up.left.and.arrow.down.right") {
                    guard let fitted = TrackCanvas.cameraFitting(everything, in: size) else { return }
                    withAnimation {
                        tookOverAt = .now
                        isFollowingRider = false
                        rotationWhileMovedByHand = 0   // north up, to take it all in
                        panCentre = fitted.center
                        metersAcross = fitted.metersAcross
                    }
                }
            }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .controlSize(.large)
        .padding(.trailing, 12)
    }
}
