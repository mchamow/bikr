import Foundation

public enum GPX {
    public struct Document: Equatable, Sendable {
        public var name: String?
        public var segments: [[TrackPoint]]
    }

    public enum ParseError: Error, Equatable {
        case invalidXML(String)
        case noPoints
    }

    /// Reads tracks (`<trk>`) from a GPX file, falling back to routes (`<rte>`)
    /// when there are none. All tracks in the file are merged into one.
    public static func parse(_ data: Data) throws(ParseError) -> Document {
        let delegate = ParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        guard parser.parse() else {
            throw .invalidXML(parser.parserError?.localizedDescription ?? "Unknown error")
        }
        let segments = (delegate.trackSegments.isEmpty ? delegate.routes : delegate.trackSegments)
            .filter { !$0.isEmpty }
        guard !segments.isEmpty else { throw .noPoints }
        return Document(name: delegate.trackName ?? delegate.metadataName, segments: segments)
    }

    public static func data(for track: Track) -> Data {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <gpx version="1.1" creator="Bikr" xmlns="http://www.topografix.com/GPX/1/1">
          <metadata><name>\(escape(track.name))</name><time>\(format(track.createdAt))</time></metadata>
          <trk>
            <name>\(escape(track.name))</name>
            <type>cycling</type>

        """
        for segment in track.segments {
            xml += "    <trkseg>\n"
            for point in segment {
                xml += "      <trkpt lat=\"\(String(format: "%.7f", point.latitude))\" lon=\"\(String(format: "%.7f", point.longitude))\">"
                if let elevation = point.elevation {
                    xml += "<ele>\(String(format: "%.1f", elevation))</ele>"
                }
                if let timestamp = point.timestamp {
                    xml += "<time>\(format(timestamp))</time>"
                }
                xml += "</trkpt>\n"
            }
            xml += "    </trkseg>\n"
        }
        xml += "  </trk>\n</gpx>\n"
        return Data(xml.utf8)
    }

    private static func format(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}

private final class ParserDelegate: NSObject, XMLParserDelegate {
    var trackSegments: [[TrackPoint]] = []
    var routes: [[TrackPoint]] = []
    var trackName: String?
    var metadataName: String?

    private var path: [String] = []
    private var point: TrackPoint?
    private var text = ""

    private let plainDates = ISO8601DateFormatter()
    private let fractionalDates: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String] = [:]) {
        let name = Self.localName(elementName)
        path.append(name)
        text = ""
        switch name {
        case "trkseg":
            trackSegments.append([])
        case "rte":
            routes.append([])
        case "trkpt", "rtept":
            if let lat = attributes["lat"].flatMap(Double.init), let lon = attributes["lon"].flatMap(Double.init),
               (-90...90).contains(lat), (-180...180).contains(lon) {
                point = TrackPoint(latitude: lat, longitude: lon)
            }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let name = Self.localName(elementName)
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parent = path.dropLast().last
        path.removeLast()
        text = ""

        switch (name, parent) {
        case ("ele", "trkpt"), ("ele", "rtept"):
            point?.elevation = Double(value)
        case ("time", "trkpt"), ("time", "rtept"):
            point?.timestamp = fractionalDates.date(from: value) ?? plainDates.date(from: value)
        case ("name", "trk") where !value.isEmpty:
            trackName = trackName ?? value
        case ("name", "metadata") where !value.isEmpty:
            metadataName = value
        case ("trkpt", _):
            if let point, !trackSegments.isEmpty { trackSegments[trackSegments.count - 1].append(point) }
            point = nil
        case ("rtept", _):
            if let point, !routes.isEmpty { routes[routes.count - 1].append(point) }
            point = nil
        default:
            break
        }
    }

    private static func localName(_ name: String) -> String {
        name.split(separator: ":").last.map(String.init) ?? name
    }
}
