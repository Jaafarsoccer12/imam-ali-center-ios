import XCTest

final class CenterUITests: XCTestCase {
    private func selectTab(_ name: String) {
        let tab = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", name)).firstMatch
        XCTAssertTrue(tab.waitForExistence(timeout: 8))
        tab.tap()
    }
    func testStoreScreenshots() {
        XCUIDevice.shared.orientation = .portrait
        XCTAssertTrue(app.buttons["Next feature"].waitForExistence(timeout: 15))
        capture("01-Home")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Next prayer,")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Prayer times"].waitForExistence(timeout: 8))
        capture("02-Prayer")
        app.buttons["Done"].tap()
        selectTab("Programs")
        XCTAssertTrue(app.buttons["Weekly schedule"].waitForExistence(timeout: 8))
        capture("03-Programs")
        selectTab("Explore")
        XCTAssertTrue(app.textFields["Search the directory"].waitForExistence(timeout: 8))
        capture("04-Explore")
        selectTab("Visit")
        XCTAssertTrue(app.staticTexts["Visit the Center."].waitForExistence(timeout: 8))
        capture("05-Visit")
    }
    let app = XCUIApplication()
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launch()
    }
    private func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
    func testHomeProgramsAndPrayer() {
        XCTAssertTrue(app.buttons["Next feature"].waitForExistence(timeout: 8))
        capture("Home")
        app.buttons["Next feature"].tap()
        XCTAssertEqual(app.buttons["Next feature"].value as? String, "Feature 2 of 5")
        let prayer = app.buttons.matching(NSPredicate(format:"label BEGINSWITH[c] %@", "Next prayer,")).firstMatch
        prayer.tap()
        XCTAssertTrue(app.staticTexts["Prayer times"].waitForExistence(timeout: 4))
        capture("Prayer")
        app.buttons["Done"].tap()
        selectTab("Programs")
        let calendarAction = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@ AND label ENDSWITH %@", "Add ", " to calendar")).firstMatch
        XCTAssertTrue(calendarAction.waitForExistence(timeout: 4))
        assertTouchSize(calendarAction)
        assertTouchSize(app.buttons["Weekly schedule"])
        capture("Programs")
        app.buttons["Seasonal programs"].tap()
        XCTAssertFalse(calendarAction.exists)
        XCTAssertTrue(app.buttons["Weekly schedule"].exists)
    }
    private func assertTouchSize(_ control: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(control.exists, file: file, line: line)
        let frame = control.frame
        let label = control.label
        let screen = app.frame
        print("Measured control \(label): \(frame.width) × \(frame.height) pt")
        XCTAssertGreaterThanOrEqual(frame.width, 44, label, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.height, 44, label, file: file, line: line)
        XCTAssertGreaterThanOrEqual(frame.minX, screen.minX - 1, label, file: file, line: line)
        XCTAssertLessThanOrEqual(frame.maxX, screen.maxX + 1, label, file: file, line: line)
    }

    func testTouchTargetsPhotoViewerAndEventDetails() {
        let photo = app.buttons["feature-photo"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        print("Measured feature photo: \(photo.frame.width) × \(photo.frame.height) pt")
        XCTAssertGreaterThan(photo.frame.width / app.frame.width, 0.89)
        XCTAssertGreaterThan(photo.frame.height, 180)
        for button in ["donate", "feature-action", "Previous feature", "Next feature"] {
            assertTouchSize(app.buttons[button])
        }
        photo.swipeLeft()
        XCTAssertEqual(app.buttons["Next feature"].value as? String, "Feature 2 of 5")
        app.buttons["Previous feature"].tap()
        photo.tap()
        XCTAssertTrue(app.staticTexts["Photo 1 of 5"].waitForExistence(timeout: 4))
        assertTouchSize(app.buttons["Next photo"])
        app.buttons["Next photo"].tap()
        XCTAssertTrue(app.staticTexts["Photo 2 of 5"].exists)
        XCTAssertTrue(app.images.firstMatch.exists)
        app.images.firstMatch.doubleTap()
        capture("Enlarged photo")
        app.buttons["Done"].tap()

        let firstEvent = app.buttons.matching(identifier: "upcoming-event").firstMatch
        if !firstEvent.isHittable { app.swipeUp() }
        firstEvent.tap()
        XCTAssertTrue(app.staticTexts["Gathering details"].waitForExistence(timeout: 4))
        assertTouchSize(app.buttons["Add to calendar"])
        app.buttons["Done"].tap()
    }

    func testAccessibilityTextAndControlLayout() {
        let normalDonate = app.buttons["donate"]
        XCTAssertTrue(normalDonate.waitForExistence(timeout: 5))
        let normalHeight = normalDonate.frame.height
        app.terminate()
        app.launchArguments = ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let largeDonate = app.buttons["donate"]
        XCTAssertTrue(largeDonate.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(largeDonate.frame.height, normalHeight + 6)
        assertTouchSize(largeDonate)
        capture("Home at largest text")
        let prayer = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Next prayer,")).firstMatch
        assertTouchSize(prayer)
        prayer.tap()
        XCTAssertTrue(app.staticTexts["Prayer times"].waitForExistence(timeout: 5))
        assertTouchSize(app.buttons["Done"])
        capture("Prayer at largest text")
        app.buttons["Done"].tap()
        selectTab("Explore")
        assertTouchSize(app.textFields["Search the directory"])
        capture("Explore at largest text")
    }

    func testReviewRecurringGatheringWithoutSaving() {
        selectTab("Programs")
        let event = app.buttons.matching(NSPredicate(format:"label BEGINSWITH %@ AND label ENDSWITH %@", "Add ", " to calendar")).firstMatch
        XCTAssertTrue(event.waitForExistence(timeout: 5))
        event.tap()
        let cancel = app.buttons["Cancel"].firstMatch
        XCTAssertTrue(cancel.waitForExistence(timeout: 10), "The system calendar editor should let the visitor review or cancel the event.")
        XCTAssertTrue(app.buttons["Add"].firstMatch.exists)
        cancel.tap()
    }
    func testExploreReaderAndVisit() {
        selectTab("Explore")
        let search = app.textFields["Search the directory"]
        XCTAssertTrue(search.waitForExistence(timeout: 4))
        assertTouchSize(search)
        capture("Explore")
        search.tap()
        search.typeText("nikah\n")
        let result = app.buttons.matching(NSPredicate(format:"label CONTAINS[c] %@", "Marriage & Nikah")).firstMatch
        XCTAssertTrue(result.waitForExistence(timeout: 3))
        result.tap()
        XCTAssertTrue(app.buttons["Page options"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 5))
        let pageHeading = app.webViews.firstMatch.descendants(matching: .any).matching(NSPredicate(format:"label CONTAINS[c] %@", "Marriage")).firstMatch
        XCTAssertTrue(pageHeading.waitForExistence(timeout: 25))
        assertTouchSize(app.buttons["Page options"])
        capture("Service detail")
        if !app.staticTexts["Saved copy"].exists {
            let pageOptions = app.buttons["Page options"]
            pageOptions.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            app.buttons["Read saved copy"].tap()
        }
        XCTAssertTrue(app.staticTexts["Saved copy"].waitForExistence(timeout: 4))
        XCTAssertTrue(pageHeading.waitForExistence(timeout: 5))
        if app.buttons["Close"].firstMatch.exists {
            app.buttons["Close"].firstMatch.tap()
        } else {
            let pageOptions = app.buttons["Page options"]
            pageOptions.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            app.buttons["Close"].firstMatch.tap()
        }
        selectTab("Visit")
        XCTAssertTrue(app.staticTexts["Visit the Center."].waitForExistence(timeout: 4))
        capture("Visit")
    }
}
