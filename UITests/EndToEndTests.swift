import XCTest

/// Goes through the app as a person does: a profile, the source list, a title,
/// a stream, and the player. It needs real addons and the network.
///
/// The sources come from the environment, because the project does not
/// recommend any source. Run it with:
///
///     TEST_RUNNER_ZS_E2E_SOURCES="$(cat my-sources.txt)" \
///     TEST_RUNNER_ZS_E2E_SHOTS=/tmp/shots \
///     xcodebuild test -scheme ZettaStream -destination 'platform=iOS Simulator,name=...'
///
/// With no sources, the test stops at the start and is skipped.
final class EndToEndTests: XCTestCase {
    private var app: XCUIApplication!
    private var shots: URL?
    private var step = 0

    override func setUpWithError() throws {
        continueAfterFailure = false
        let environment = ProcessInfo.processInfo.environment
        guard let sources = environment["ZS_E2E_SOURCES"], !sources.isEmpty else {
            throw XCTSkip("ZS_E2E_SOURCES is not set.")
        }
        if let path = environment["ZS_E2E_SHOTS"] {
            shots = URL(fileURLWithPath: path)
            try? FileManager.default.createDirectory(at: shots!, withIntermediateDirectories: true)
        }
        app = XCUIApplication()
        app.launch()
    }

    /// Keeps a picture of the screen, so that a person can look at each step.
    private func shot(_ name: String) {
        step += 1
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let shots {
            try? screenshot.pngRepresentation.write(to: shots.appendingPathComponent(String(format: "%02d-%@.png", step, name)))
        }
    }

    private func waitFor(_ element: XCUIElement, _ seconds: TimeInterval = 30, _ what: String) {
        XCTAssertTrue(element.waitForExistence(timeout: seconds), "\(what) does not show.")
    }

    func testAViewerPlaysATitleFromTheSourceList() throws {
        waitFor(app.staticTexts["Who is watching?"], 15, "The profile screen")
        shot("profiles")
        app.buttons["Main"].firstMatch.tap()

        // Add the sources on the Sources screen, as a person pastes them.
        app.tabBars.buttons["Settings"].tap()
        // The row says the number of sources after its name, such as "Sources, 43 sources".
        let sourcesRow = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sources'")).firstMatch
        waitFor(sourcesRow, 10, "The Sources entry")
        shot("settings")
        sourcesRow.tap()
        let editor = app.textViews.firstMatch
        waitFor(editor, 10, "The source editor")
        editor.tap()
        editor.typeText(ProcessInfo.processInfo.environment["ZS_E2E_SOURCES"]!)
        app.buttons["Save"].tap()
        shot("sources-saved")

        // Home fills with the rows of the addons.
        app.tabBars.buttons["Home"].tap()
        let poster = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card:'")).firstMatch
        waitFor(poster, 60, "A poster on Home")
        sleep(3)
        shot("home")
        poster.tap()

        // The title page, then Play.
        let play = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Watch' OR label BEGINSWITH 'Resume'")).firstMatch
        waitFor(play, 30, "The Play button")
        sleep(2)
        shot("title")
        play.tap()

        // Auto play finds a stream, and the player starts.
        let player = app.otherElements["player"]
        waitFor(player, 90, "The player")
        sleep(15)
        shot("player")
        player.tap()
        sleep(1)
        shot("player-controls")
    }
}
