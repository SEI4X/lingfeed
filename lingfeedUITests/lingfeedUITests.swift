//
//  lingfeedUITests.swift
//  lingfeedUITests
//
//  Created by Alexey Mashkov on 18.04.2026.
//

import XCTest

final class lingfeedUITests: XCTestCase {

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
    func testFeedShowsWrongAnswerFeedback() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--use-mock-backend",
            "--ui-test-feed-ready",
            "-AppleLanguages",
            "(en)",
            "-AppleLocale",
            "en_US"
        ]
        app.launch()

        XCTAssertTrue(app.staticTexts["Good morning"].waitForExistence(timeout: 8))

        let answerField = app.firstTextInput
        XCTAssertTrue(answerField.waitForExistence(timeout: 2))
        answerField.tap()
        answerField.typeText("wrong")
        app.dismissKeyboardIfNeeded()

        let submitButton = app.buttons["Check"]
        XCTAssertTrue(submitButton.waitForExistence(timeout: 2))
        submitButton.tap()

        XCTAssertTrue(app.staticTexts["Almost."].waitForExistence(timeout: 4))
        XCTAssertTrue(app.staticTexts["Your answer: wrong"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Correct answer: Buenos dias"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}

private extension XCUIApplication {
    func element(id: String) -> XCUIElement {
        descendants(matching: .any)[id]
    }

    var firstTextInput: XCUIElement {
        let textField = textFields.firstMatch
        if textField.exists {
            return textField
        }
        return textViews.firstMatch
    }

    func dismissKeyboardIfNeeded() {
        guard keyboards.firstMatch.exists else { return }
        coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.18)).tap()
    }
}
