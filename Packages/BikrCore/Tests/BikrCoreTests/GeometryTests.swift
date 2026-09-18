import Foundation
import Testing
@testable import BikrCore

struct GeometryTests {
    let home = TrackPoint(latitude: 50, longitude: 20)

    func moved(east: Double = 0, north: Double = 0) -> TrackPoint {
        let metersPerDegree = Fixtures.metersPerDegree
        return TrackPoint(
            latitude: home.latitude + north / metersPerDegree,
            longitude: home.longitude + east / (metersPerDegree * cos(home.latitude * .pi / 180))
        )
    }

    @Test(arguments: [(0.0, 100.0, 0.0), (100, 0, 90), (0, -100, 180), (-100, 0, 270), (100, 100, 45)])
    func bearingPointsTheRightWay(east: Double, north: Double, expected: Double) {
        let bearing = home.bearing(to: moved(east: east, north: north))
        #expect(abs(bearing - expected) < 0.5)
    }

    @Test func offsetIsInMeters() {
        let there = moved(east: 300, north: -150)
        let offset = home.offset(to: there)
        #expect(abs(offset.east - 300) < 0.5)
        #expect(abs(offset.north + 150) < 0.5)
    }

    @Test func movingAndMeasuringAreInverses() {
        let there = home.moved(east: -250, north: 400)
        let offset = home.offset(to: there)
        #expect(abs(offset.east + 250) < 0.5)
        #expect(abs(offset.north - 400) < 0.5)
    }

    @Test func offsetOfThePointItself() {
        let offset = home.offset(to: home)
        #expect(offset.east == 0)
        #expect(offset.north == 0)
    }
}
