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
        /// Keep the rider in the middle, showing this many meters across.
        case rider(TrackPoint, metersAcross: Double)
    }

    var lines: [Line]
    var focus: Focus
    var rider: Rider?
    /// Dashed line from the rider back to the nearest point of the track.
    var wayBack: (from: TrackPoint, to: TrackPoint)?

    var body: some View {
        Canvas { context, size in
            guard let projection = Projection(lines: lines, focus: focus, rider: rider, size: size) else { return }

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
                path.move(to: projection.point(wayBack.from))
                path.addLine(to: projection.point(wayBack.to))
                context.stroke(path, with: .color(.red), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [6, 8]))
            }

            if let rider {
                draw(rider, in: &context, projection)
            }
            drawNorthArrow(in: &context, size: size)
            drawScaleBar(in: &context, size: size, metersPerPoint: projection.metersPerPoint)
        }
        .background(Color(.secondarySystemBackground))
    }

    /// Skips points that would land on the same spot, so a long ride doesn't
    /// cost thousands of path segments.
    private func path(of segment: [TrackPoint], _ projection: Projection) -> Path {
        var path = Path()
        var last: CGPoint?
        for point in segment {
            let next = projection.point(point)
            if let last, abs(next.x - last.x) < 1.5, abs(next.y - last.y) < 1.5 { continue }
            if last == nil { path.move(to: next) } else { path.addLine(to: next) }
            last = next
        }
        return path
    }

    private func draw(_ rider: Rider, in context: inout GraphicsContext, _ projection: Projection) {
        let center = projection.point(rider.position)
        if let course = rider.course {
            // A triangle pointing the way the rider is travelling.
            var arrow = Path()
            arrow.move(to: CGPoint(x: 0, y: -18))
            arrow.addLine(to: CGPoint(x: 11, y: 12))
            arrow.addLine(to: CGPoint(x: 0, y: 6))
            arrow.addLine(to: CGPoint(x: -11, y: 12))
            arrow.closeSubpath()
            let placed = arrow
                .applying(CGAffineTransform(rotationAngle: course * .pi / 180))
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
        needle.move(to: CGPoint(x: center.x, y: center.y - 16))
        needle.addLine(to: CGPoint(x: center.x + 7, y: center.y + 8))
        needle.addLine(to: CGPoint(x: center.x - 7, y: center.y + 8))
        needle.closeSubpath()
        context.fill(needle, with: .color(.secondary))
        context.draw(
            context.resolve(Text("N").font(.caption2.weight(.bold)).foregroundStyle(.secondary)),
            at: CGPoint(x: center.x, y: center.y + 20)
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

/// Turns coordinates into points on the canvas.
private struct Projection {
    let center: TrackPoint
    let metersPerPoint: Double
    let size: CGSize

    init?(lines: [TrackCanvas.Line], focus: TrackCanvas.Focus, rider: TrackCanvas.Rider?, size: CGSize) {
        guard size.width > 0, size.height > 0 else { return nil }
        self.size = size

        switch focus {
        case .rider(let position, let metersAcross):
            center = position
            metersPerPoint = metersAcross / Double(size.width)
        case .fit:
            let points = lines.flatMap { $0.segments.flatMap(\.self) } + [rider?.position].compactMap(\.self)
            guard !points.isEmpty else { return nil }
            let latitudes = points.map(\.latitude), longitudes = points.map(\.longitude)
            let middle = TrackPoint(
                latitude: ((latitudes.min() ?? 0) + (latitudes.max() ?? 0)) / 2,
                longitude: ((longitudes.min() ?? 0) + (longitudes.max() ?? 0)) / 2
            )
            let offsets = points.map { middle.offset(to: $0) }
            let east = (offsets.map(\.east).max() ?? 0) - (offsets.map(\.east).min() ?? 0)
            let north = (offsets.map(\.north).max() ?? 0) - (offsets.map(\.north).min() ?? 0)
            center = middle
            metersPerPoint = max(
                max(east / Double(size.width), north / Double(size.height)) * 1.15,
                50 / Double(size.width)   // a very short track still needs some scale
            )
        }
    }

    func point(_ coordinate: TrackPoint) -> CGPoint {
        let offset = center.offset(to: coordinate)
        return CGPoint(
            x: size.width / 2 + offset.east / metersPerPoint,
            y: size.height / 2 - offset.north / metersPerPoint
        )
    }
}
