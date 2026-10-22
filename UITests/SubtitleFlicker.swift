import XCTest

/// Records the screen ten times a second while a film plays with subtitles, once with
/// the ambient side bars and once with black side bars. The pictures go to ZS_E2E_SHOTS,
/// where a script counts the frames that show the subtitle. It needs real sources.
final class SubtitleFlicker: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        let environment = ProcessInfo.processInfo.environment
        guard let sources = environment["ZS_E2E_SOURCES"], !sources.isEmpty, environment["ZS_E2E_SHOTS"] != nil else {
            throw XCTSkip("ZS_E2E_SOURCES or ZS_E2E_SHOTS is not set.")
        }
        app = XCUIApplication()
        app.launch()
        let main = app.buttons["Main"].firstMatch
        if main.waitForExistence(timeout: 15) { main.tap() }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons["Settings"].tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sources'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        if row.label.contains("0 sources") {
            row.tap()
            let editor = app.textViews.firstMatch
            XCTAssertTrue(editor.waitForExistence(timeout: 10))
            editor.tap()
            editor.typeText(sources)
            app.buttons["Save"].tap()
            app.navigationBars.buttons.firstMatch.tap()
        }
        let subtitles = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Subtitles, Off'")).firstMatch
        if subtitles.waitForExistence(timeout: 3) { subtitles.tap() }
    }

    private func setSideBars(_ label: String) {
        app.tabBars.buttons["Settings"].tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Side bars'")).firstMatch
        for _ in 0..<6 where !row.isHittable { app.swipeUp() }
        row.tap()
        app.buttons[label].firstMatch.tap()
        sleep(1)
    }

    private func record(_ name: String) throws {
        app.tabBars.buttons["Search"].tap()
        let play = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Watch' OR label BEGINSWITH 'Resume'")).firstMatch
        // The second time, the page of the film is still open on the Search tab.
        if !play.waitForExistence(timeout: 3) {
            let field = app.textFields.firstMatch
            field.tap()
            field.typeText("The Shawshank Redemption\n")
            let card = app.buttons["card:tt0111161"].firstMatch
            XCTAssertTrue(card.waitForExistence(timeout: 60))
            card.tap()
            XCTAssertTrue(play.waitForExistence(timeout: 30))
        }
        play.tap()
        let player = app.otherElements["player"]
        XCTAssertTrue(player.waitForExistence(timeout: 120))
        // The slider shows when the length of the film is known. Then 3 goes to 30 percent, where people speak.
        let end = Date().addingTimeInterval(180)
        while Date() < end && !app.sliders.firstMatch.exists {
            player.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
            _ = app.sliders.firstMatch.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(app.sliders.firstMatch.exists, "The film does not play.")
        app.typeKey("3", modifierFlags: [])
        sleep(15)
        let folder = URL(fileURLWithPath: ProcessInfo.processInfo.environment["ZS_E2E_SHOTS"]!).appendingPathComponent(name)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for frame in 0..<120 {
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: folder.appendingPathComponent(String(format: "%03d.png", frame)))
            usleep(100_000)
        }
        player.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        app.buttons["Close"].tap()
        sleep(2)
    }

    func testRecordWithBothSideBars() throws {
        setSideBars("Ambient blur")
        try record("ambient")
        setSideBars("Black")
        try record("black")
    }
}
