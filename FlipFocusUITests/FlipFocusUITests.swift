//
//  FlipFocusUITests.swift
//  FlipFocusUITests
//
//  Created by Rayhan Mohamed on 3/18/26.
//

import XCTest

final class FlipFocusUITests: XCTestCase {

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
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }

    // SCRATCH: pause a session and dump frames so they can be inspected off-device.
    @MainActor
    func testPausedSweepFrames() throws {
        let app = XCUIApplication()
        app.launch()

        app.buttons["Freeze"].tap()          // pin the clock at 01:27:43
        app.buttons["Flip"].tap()            // pause — this is when the sweep should play

        func shot(_ name: String) {
            let data = XCUIScreen.main.screenshot().pngRepresentation
            let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            try? data.write(to: dir.appendingPathComponent("\(name).png"))
        }

        shot("pause-0")                      // right after the pause
        Thread.sleep(forTimeInterval: 0.35)
        shot("pause-1")                      // mid-sweep
        Thread.sleep(forTimeInterval: 1.5)
        shot("pause-2")                      // settled
    }
}
