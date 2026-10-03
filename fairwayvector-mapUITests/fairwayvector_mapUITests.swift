//
//  fairwayvector_mapUITests.swift
//  fairwayvector-mapUITests
//
//  Created by Joel spolen on 2026-09-28.
//

import XCTest

final class fairwayvector_mapUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // XCUIAutomation Documentation
        // https://developer.apple.com/documentation/xcuiautomation
    }

        @MainActor
        func testTrajectoryOpensWithoutSplashAndCanClose() {
            let app = XCUIApplication()
            app.launch()

            let openTrajectory = app.buttons["Explore Trajectory"]
            XCTAssertTrue(openTrajectory.waitForExistence(timeout: 12))
            openTrajectory.tap()

            let trajectoryHome = app.staticTexts["Know which club to hit."]
            XCTAssertTrue(trajectoryHome.waitForExistence(timeout: 5))
            XCTAssertEqual(app.tabBars.count, 1)
            XCTAssertFalse(app.staticTexts["Know your flight"].exists)
            app.tabBars.buttons["Home"].tap()
            XCTAssertTrue(openTrajectory.waitForExistence(timeout: 5))
        }

        @MainActor
        func testHCPProjectionOpensWithoutSplash() {
            let app = XCUIApplication()
            app.launch()

            let openHCP = app.buttons["View Handicap"]
            XCTAssertTrue(openHCP.waitForExistence(timeout: 12))
            openHCP.tap()

            XCTAssertTrue(app.staticTexts["Plan the score or stableford points that move your handicap."].waitForExistence(timeout: 8))
            XCTAssertEqual(app.tabBars.count, 1)
            XCTAssertFalse(app.staticTexts["Know your place on the course"].exists)
            app.tabBars.buttons["Home"].tap()
            XCTAssertTrue(openHCP.waitForExistence(timeout: 5))
        }

    @MainActor
    func testSharedProfileAndSettings() {
        let app = XCUIApplication()
        app.launch()
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 12))
        profileTab.tap()
        XCTAssertTrue(app.staticTexts["Clubs & launch profile"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Distance units"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
    }

    @MainActor
    func testCourseSelectorExplainsMissingGolfAPIKey() {
        let app = XCUIApplication()
        app.launch()
        let courseTab = app.tabBars.buttons["Course"]
        XCTAssertTrue(courseTab.waitForExistence(timeout: 12))
        courseTab.tap()

        XCTAssertTrue(app.staticTexts["Golf API key not configured. Add GOLF_API_KEY in the app target’s build settings."].waitForExistence(timeout: 5))
        let searchField = app.textFields["golf-club-search-field"]
        XCTAssertTrue(searchField.exists)
        searchField.tap()
        searchField.typeText("Åre")
        app.buttons["Search Swedish clubs"].tap()
        XCTAssertTrue(app.staticTexts["Golf API is not configured. Add GOLF_API_KEY to the app target's build settings."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testWedgeMatrixUsesPracticeSection() {
        let app = XCUIApplication()
        app.launch()

        let wedgeShortcut = app.buttons["Explore Wedge Matrix"]
        XCTAssertTrue(wedgeShortcut.waitForExistence(timeout: 12))
        wedgeShortcut.tap()
        XCTAssertTrue(app.navigationBars["Wedge Matrix"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.tabBars.count, 1)
        XCTAssertTrue(app.tabBars.buttons["Practice"].exists)

        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.buttons["Wedge bag & matrix"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDistanceUnitsAreSharedWithWedgeMatrix() {
        let app = XCUIApplication()
        app.launch()
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 12))
        profileTab.tap()
        let settings = app.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()

        let meters = app.buttons["Meters"]
        XCTAssertTrue(meters.waitForExistence(timeout: 5))
        meters.tap()
        app.buttons["Done"].tap()
        app.buttons["Wedge bag & matrix"].tap()
        XCTAssertTrue(app.navigationBars["Wedge Matrix"].waitForExistence(timeout: 5))
        app.buttons["Matrix"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", " m")).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
