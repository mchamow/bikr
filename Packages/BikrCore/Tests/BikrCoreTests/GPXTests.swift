import Foundation
import Testing
@testable import BikrCore

struct GPXTests {
    @Test func roundTripKeepsSegmentsAndPoints() throws {
        var points = Fixtures.northbound(count: 3) { Double(200 + $0) }
        points[2].elevation = nil
        let track = Track(name: "Morning <loop> & back", origin: .recorded, segments: [points, Fixtures.northbound(count: 2)])

        let document = try GPX.parse(GPX.data(for: track))

        #expect(document.name == "Morning <loop> & back")
        #expect(document.segments.count == 2)
        #expect(document.segments[0].count == 3)
        #expect(document.segments[0][0].elevation == 200)
        #expect(document.segments[0][2].elevation == nil)
        #expect(document.segments[0][1].timestamp == points[1].timestamp)
        #expect(abs(document.segments[0][2].latitude - points[2].latitude) < 1e-6)
    }

    @Test func readsTypicalExportFromAnotherApp() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx xmlns="http://www.topografix.com/GPX/1/1" version="1.1" creator="Other">
          <metadata><name>Metadata name</name></metadata>
          <trk><name>Gravel Sunday</name><trkseg>
            <trkpt lat="50.0" lon="20.0"><ele>210.4</ele><time>2026-09-13T08:00:00.250Z</time></trkpt>
            <trkpt lat="50.001" lon="20.001"><ele>212</ele><time>2026-09-13T08:00:05Z</time></trkpt>
            <trkpt lat="bad" lon="20.002"></trkpt>
          </trkseg></trk>
        </gpx>
        """
        let document = try GPX.parse(Data(xml.utf8))
        #expect(document.name == "Gravel Sunday")
        #expect(document.segments == [[
            TrackPoint(latitude: 50, longitude: 20, elevation: 210.4, timestamp: Date(timeIntervalSince1970: 1_789_286_400.25)),
            TrackPoint(latitude: 50.001, longitude: 20.001, elevation: 212, timestamp: Date(timeIntervalSince1970: 1_789_286_405)),
        ]])
    }

    @Test func fallsBackToRoutes() throws {
        let xml = """
        <gpx version="1.1"><metadata><name>Planned</name></metadata>
          <rte><rtept lat="1" lon="2"/><rtept lat="1.1" lon="2.1"/></rte>
        </gpx>
        """
        let document = try GPX.parse(Data(xml.utf8))
        #expect(document.name == "Planned")
        #expect(document.segments.map(\.count) == [2])
    }

    @Test func rejectsFilesWithoutPoints() {
        #expect(throws: GPX.ParseError.noPoints) {
            try GPX.parse(Data("<gpx><trk><trkseg></trkseg></trk></gpx>".utf8))
        }
    }

    @Test func rejectsMalformedXML() {
        #expect {
            try GPX.parse(Data("<gpx><trk>".utf8))
        } throws: { error in
            if case .invalidXML = error as? GPX.ParseError { true } else { false }
        }
    }
}
