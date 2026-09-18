import XCTest

/// Smoke test of the main flow: record a ride, save it, then follow it.
/// The simulator has to be moving, which `scripts/ui-test.sh` takes care of.
final class RideFlowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() async throws {
        // Bikr keeps GPS (and itself) alive while riding, so leaving it running
        // makes the test run hang on teardown.
        await MainActor.run { XCUIApplication().terminate() }
    }

    @MainActor
    func testRecordSaveAndFollowARide() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.buttons["Start Ride"].waitForExistence(timeout: 10))
        app.buttons["Start Ride"].tap()
        allowLocationAccessIfAsked()

        // Recording: pause and finish replace the start button.
        XCTAssertTrue(app.buttons["Finish"].waitForExistence(timeout: 10))

        // Ride for a while: the live stats have to show a distance above zero.
        XCTAssertTrue(waitForRecordedDistance(in: app), "No distance was recorded while the simulator was moving")

        // Speed shows a value, not the "–" placeholder, even though the
        // Simulator's fake locations carry no speed of their own.
        XCTAssertFalse(app.staticTexts["–"].exists, "No speed shown while recording")

        // Pause and resume, which starts a new segment.
        app.buttons["Pause"].tap()
        XCTAssertTrue(app.buttons["Resume"].waitForExistence(timeout: 5))
        app.buttons["Resume"].tap()
        XCTAssertTrue(app.buttons["Pause"].waitForExistence(timeout: 5))
        Thread.sleep(forTimeInterval: 10)

        app.buttons["Finish"].tap()
        app.buttons["Save Ride"].tap()
        XCTAssertTrue(app.buttons["Start Ride"].waitForExistence(timeout: 5))

        // The ride is saved, with the distance it covered...
        app.tabBars.buttons["Tracks"].tap()
        // Rows are buttons; section headers are not.
        let ride = app.collectionViews.buttons.element(boundBy: 0)
        XCTAssertTrue(ride.waitForExistence(timeout: 10), "The saved ride is missing from the Tracks tab:\n\(app.debugDescription)")
        XCTAssertTrue(hasPositiveDistance(ride.label), "The ride was saved without distance: \(ride.label)")

        // ...and can be followed back on the Ride tab.
        ride.tap()
        let follow = app.buttons["Follow This Track"]
        XCTAssertTrue(follow.waitForExistence(timeout: 15), "The track's details didn't open:\n\(app.debugDescription)")
        follow.tap()
        XCTAssertTrue(app.buttons["Stop Following"].waitForExistence(timeout: 10), "Following didn't start")

        app.buttons["Stop Following"].tap()
        XCTAssertTrue(app.buttons["Follow a Track"].waitForExistence(timeout: 5))
    }

    /// Waits until some stat on screen reads like a distance above zero.
    @MainActor
    private func waitForRecordedDistance(in app: XCUIApplication, timeout: TimeInterval = 30) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if app.staticTexts.allElementsBoundByIndex.contains(where: { hasPositiveDistance($0.label) }) {
                return true
            }
            Thread.sleep(forTimeInterval: 1)
        }
        return false
    }

    /// True for "320 m" or "1,2 km", false for "0 m" and for speeds like "24 km/h".
    private func hasPositiveDistance(_ text: String) -> Bool {
        let pattern = #"(\d+(?:[.,]\d+)?)\s?(m|km|ft|mi)(?![/\w])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        return regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).contains { match in
            guard let range = Range(match.range(at: 1), in: text) else { return false }
            return (Double(text[range].replacingOccurrences(of: ",", with: ".")) ?? 0) > 0
        }
    }

    /// Answers the location permission prompt on a simulator that hasn't been
    /// asked yet. The simulator's language is whatever the machine runs in, so
    /// this can't rely on English button labels.
    @MainActor
    private func allowLocationAccessIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let prompt = springboard.alerts.firstMatch
        guard prompt.waitForExistence(timeout: 15) else {
            print("No location prompt appeared; this simulator has been asked already.")
            return
        }

        let buttons = prompt.buttons.allElementsBoundByIndex
        print("Location prompt: \(buttons.map(\.label))")
        // Fall back to the first button: the two "allow" choices come before
        // "don't allow", whatever language the simulator runs in.
        let allow = buttons.first { ["Allow While Using App", "Allow Once"].contains($0.label) } ?? buttons.first
        allow?.tap()
    }
}
