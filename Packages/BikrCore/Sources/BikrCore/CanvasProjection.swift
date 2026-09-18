import Foundation

/// Turns coordinates into positions on a drawing, the way a map view does:
/// somewhere to look from, how much to show, which way is up, and where on the
/// drawing that centre sits.
///
/// Coordinates are in points with the origin at the top left, as screens are.
public struct CanvasProjection: Sendable {
    public var centre: TrackPoint
    public var metersPerPoint: Double
    public var width: Double
    public var height: Double
    /// The bearing that points up the screen. 0 leaves north up; feeding the
    /// rider's course turns the drawing the way they are going.
    public var rotation: Double
    /// Where `centre` sits on the drawing, 0...1 from the top left. Pushing it
    /// down the screen shows more of what lies ahead.
    public var focusX: Double
    public var focusY: Double

    public init(
        centre: TrackPoint,
        metersPerPoint: Double,
        width: Double,
        height: Double,
        rotation: Double = 0,
        focusX: Double = 0.5,
        focusY: Double = 0.5
    ) {
        self.centre = centre
        self.metersPerPoint = metersPerPoint
        self.width = width
        self.height = height
        self.rotation = rotation
        self.focusX = focusX
        self.focusY = focusY
    }

    public func point(for coordinate: TrackPoint) -> (x: Double, y: Double) {
        let offset = centre.offset(to: coordinate)
        let (east, north) = turned(east: offset.east, north: offset.north)
        return (
            x: width * focusX + east / metersPerPoint,
            y: height * focusY - north / metersPerPoint
        )
    }

    /// The coordinate `x`, `y` points away from the centre, for dragging the
    /// drawing about.
    public func coordinate(movedBy x: Double, _ y: Double) -> TrackPoint {
        let (east, north) = turned(east: x * metersPerPoint, north: -y * metersPerPoint, backwards: true)
        return centre.moved(east: east, north: north)
    }

    private func turned(east: Double, north: Double, backwards: Bool = false) -> (Double, Double) {
        guard rotation != 0 else { return (east, north) }
        let angle = (backwards ? -rotation : rotation) * .pi / 180
        return (
            east * cos(angle) - north * sin(angle),
            east * sin(angle) + north * cos(angle)
        )
    }
}
