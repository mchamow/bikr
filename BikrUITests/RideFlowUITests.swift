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

        // A track that was ridden brings its own ghost to race.
        XCTAssertTrue(app.descendants(matching: .any)["ghostScore"].waitForExistence(timeout: 15),
                      "No ghost on a track that was recorded:\n\(app.debugDescription)")

        app.buttons["Stop Following"].tap()
        XCTAssertTrue(app.buttons["Follow a Track"].waitForExistence(timeout: 5))
    }

    /// A ride cut short by iOS shutting the app down is offered back on the
    /// next launch, not lost.
    @MainActor
    func testRecoversAnInterruptedRide() {
        let app = XCUIApplication()
        app.launch()

        recordUntilMoving(app)

        app.terminate()   // as if iOS had shut the app down mid-ride
        app.launch()

        let save = app.buttons["Save Ride"]
        XCTAssertTrue(save.waitForExistence(timeout: 15), "The interrupted ride wasn't offered back:\n\(app.debugDescription)")
        save.tap()

        let ride = app.collectionViews.buttons.element(boundBy: 0)
        XCTAssertTrue(ride.waitForExistence(timeout: 10), "The recovered ride is missing from the Tracks tab")
        XCTAssertTrue(hasPositiveDistance(ride.label), "The recovered ride has no distance: \(ride.label)")
    }

    /// Putting the decision off and starting another ride keeps the
    /// interrupted one rather than overwriting it.
    @MainActor
    func testKeepsAnInterruptedRideWhenTheNextOneStarts() {
        let app = XCUIApplication()
        app.launch()
        recordUntilMoving(app)

        app.terminate()
        app.launch()
        let later = app.buttons["Decide Later"]
        XCTAssertTrue(later.waitForExistence(timeout: 15), "The interrupted ride wasn't offered back")
        later.tap()

        // Starting a ride has to save the interrupted one first.
        app.buttons["Start Ride"].tap()
        XCTAssertTrue(app.buttons["Finish"].waitForExistence(timeout: 10))
        app.buttons["Finish"].tap()
        app.buttons["Discard Ride"].tap()

        app.tabBars.buttons["Tracks"].tap()
        let ride = app.collectionViews.buttons.element(boundBy: 0)
        XCTAssertTrue(ride.waitForExistence(timeout: 10), "The interrupted ride was lost")
        XCTAssertTrue(hasPositiveDistance(ride.label), "The interrupted ride has no distance: \(ride.label)")
    }

    /// With no connection there is no map, but the ride still records: GPS
    /// never needed the network.
    @MainActor
    func testRecordsWithoutAConnection() {
        let app = XCUIApplication()
        app.launchEnvironment["BIKR_FORCE_OFFLINE"] = "1"
        app.launchEnvironment["BIKR_RETURN_TO_NAVIGATION"] = "3"
        app.launch()

        XCTAssertTrue(app.descendants(matching: .any)["offlineBanner"].waitForExistence(timeout: 15),
                      "No offline notice shown:\n\(app.debugDescription)")

        recordUntilMoving(app)

        // The drawn map behaves like a map: dragging it stops it following the
        // rider, and a button brings them back to the middle.
        XCTAssertTrue(app.buttons["Show the Whole Track"].exists, "No way to see the whole track")
        XCTAssertFalse(app.buttons["Centre on Me"].exists, "Already off-centre before anything was dragged")
        dragTheMap(app)
        let centreOnMe = app.buttons["Centre on Me"]
        XCTAssertTrue(centreOnMe.waitForExistence(timeout: 5),
                      "Dragging the map didn't free it from the rider:\n\(app.debugDescription)")

        // Left alone, the map goes back to following the rider by itself.
        XCTAssertTrue(waitForItToGo(centreOnMe, within: 20), "The map never went back to following the rider")

        // And it can be brought back by hand, without waiting.
        dragTheMap(app)
        XCTAssertTrue(centreOnMe.waitForExistence(timeout: 5))
        centreOnMe.tap()
        XCTAssertTrue(waitForItToGo(centreOnMe, within: 5), "Still off-centre after centring")

        app.buttons["Finish"].tap()
        app.buttons["Discard Ride"].tap()
        XCTAssertTrue(app.buttons["Start Ride"].waitForExistence(timeout: 5))
    }

    /// A deliberate drag across the map. A flick is too quick to be taken for
    /// a drag on a busy machine.
    @MainActor
    private func dragTheMap(_ app: XCUIApplication) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.35))
        let to = app.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.4))
        from.press(forDuration: 0.2, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.2)
    }

    /// Waits for something on screen to go away.
    @MainActor
    private func waitForItToGo(_ element: XCUIElement, within seconds: TimeInterval) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter.wait(for: [gone], timeout: seconds) == .completed
    }

    /// Starts recording and waits until the ride has covered some ground.
    @MainActor
    private func recordUntilMoving(_ app: XCUIApplication) {
        XCTAssertTrue(app.buttons["Start Ride"].waitForExistence(timeout: 10))
        app.buttons["Start Ride"].tap()
        allowLocationAccessIfAsked()
        XCTAssertTrue(waitForRecordedDistance(in: app),
                      "No distance was recorded while the simulator was moving:\n\(app.debugDescription)")
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
        // "While using" is what we want: "Allow Once" is forgotten when the app
        // relaunches. It is the second of the three buttons in every language,
        // so fall back to that rather than to the first one.
        let whileUsing = buttons.first { $0.label == "Allow While Using App" }
        let byPosition = buttons.count >= 3 ? buttons[1] : buttons.first
        (whileUsing ?? byPosition)?.tap()
    }
}
