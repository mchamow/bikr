import Foundation
import Testing
@testable import BikrCore

struct CanvasProjectionTests {
    let centre = TrackPoint(latitude: 50, longitude: 20)

    /// 400 points across showing 400 m: one meter per point.
    func projection(rotation: Double = 0, focusY: Double = 0.5) -> CanvasProjection {
        CanvasProjection(centre: centre, metersPerPoint: 1, width: 400, height: 800,
                         rotation: rotation, focusY: focusY)
    }

    @Test func theCentreSitsInTheMiddle() {
        let point = projection().point(for: centre)
        #expect(abs(point.x - 200) < 0.01)
        #expect(abs(point.y - 400) < 0.01)
    }

    @Test func northIsUpUntilTheDrawingIsTurned() {
        let north = projection().point(for: Fixtures.moved(from: centre, north: 100))
        #expect(abs(north.x - 200) < 0.5)
        #expect(abs(north.y - 300) < 0.5, "100 m north should be 100 points up the screen")

        let east = projection().point(for: Fixtures.moved(from: centre, east: 100))
        #expect(abs(east.x - 300) < 0.5)
        #expect(abs(east.y - 400) < 0.5)
    }

    @Test(arguments: [(90.0, "east"), (180.0, "south"), (270.0, "west")])
    func turningPutsTheWayYouAreGoingAtTheTop(rotation: Double, name: String) {
        // Whichever way the drawing is turned, the bearing it is turned to
        // comes out at the top of the screen.
        let ahead: TrackPoint = switch rotation {
        case 90: Fixtures.moved(from: centre, east: 100)
        case 180: Fixtures.moved(from: centre, north: -100)
        default: Fixtures.moved(from: centre, east: -100)
        }
        let point = projection(rotation: rotation).point(for: ahead)
        #expect(abs(point.x - 200) < 0.5, "\(name) should be straight ahead")
        #expect(abs(point.y - 300) < 0.5, "\(name) should be 100 points up the screen")
    }

    @Test func theRiderCanSitLowerSoMoreOfTheWayAheadShows() {
        let point = projection(focusY: 0.75).point(for: centre)
        #expect(abs(point.y - 600) < 0.01)
    }

    @Test func draggingMovesTheCentreTheOtherWay() {
        // Dragging the drawing 50 points right moves what we are looking at
        // 50 m west.
        let moved = projection().coordinate(movedBy: -50, 0)
        let offset = centre.offset(to: moved)
        #expect(abs(offset.east + 50) < 0.5)
        #expect(abs(offset.north) < 0.5)
    }

    @Test func draggingRespectsHowTheDrawingIsTurned() {
        // Turned to face east, dragging downwards moves west — behind the rider.
        let moved = projection(rotation: 90).coordinate(movedBy: 0, 50)
        let offset = centre.offset(to: moved)
        #expect(abs(offset.east + 50) < 0.5)
        #expect(abs(offset.north) < 0.5)
    }
}
