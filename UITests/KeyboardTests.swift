import XCTest

/// Checks the keyboard shortcuts of the tabs and the voice search button. It needs no sources.
final class KeyboardTests: XCTestCase {
    func testCommandAndANumberOpenATabAndTheMicrophoneAsksForAccess() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let main = app.buttons["Main"].firstMatch
        if main.waitForExistence(timeout: 15) { main.tap() }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "The tabs do not show.")

        app.typeKey("2", modifierFlags: .command)
        XCTAssertTrue(app.buttons["Voice search"].waitForExistence(timeout: 5), "Command 2 does not open Search.")
        app.typeKey("5", modifierFlags: .command)
        XCTAssertTrue(app.staticTexts["Switch profile"].waitForExistence(timeout: 5), "Command 5 does not open Settings.")
        app.typeKey("2", modifierFlags: .command)

        app.buttons["Voice search"].tap()
        // The first time, the system asks for speech recognition and the microphone.
        // After a refusal, the app shows a message.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let alert = springboard.alerts.firstMatch
        let refused = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Voice search needs'")).firstMatch
        var asked = false
        for _ in 0..<20 where !asked {
            asked = alert.exists || refused.exists
            if !asked { usleep(500_000) }
        }
        XCTAssertTrue(asked, "Voice search does not ask for access.")
        if alert.exists { alert.buttons.element(boundBy: 0).tap() }
        XCTAssertEqual(app.state, .runningForeground)
    }
}
