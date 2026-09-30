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

            let openTrajectory = app.buttons["Open Trajectory"]
            XCTAssertTrue(openTrajectory.waitForExistence(timeout: 12))
            openTrajectory.tap()

            let setupTitle = app.navigationBars["Profile Setup"]
            let trajectoryHome = app.staticTexts["Know which club to hit."]
            XCTAssertTrue(setupTitle.waitForExistence(timeout: 5) || trajectoryHome.waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts["Know your flight"].exists)

            if setupTitle.exists {
                app.buttons["Close"].tap()
            } else {
                app.buttons["Done"].tap()
            }

            XCTAssertTrue(openTrajectory.waitForExistence(timeout: 5))
        }

        @MainActor
        func testHCPProjectionOpensWithoutSplash() {
            let app = XCUIApplication()
            app.launch()

            let openHCP = app.buttons["Open HCP Projection"]
            XCTAssertTrue(openHCP.waitForExistence(timeout: 12))
            openHCP.tap()

            XCTAssertTrue(app.staticTexts["Plan the score or stableford points that move your handicap."].waitForExistence(timeout: 8))
            XCTAssertFalse(app.staticTexts["Know your place on the course"].exists)
            app.buttons["Done"].tap()
            XCTAssertTrue(openHCP.waitForExistence(timeout: 5))
        }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
