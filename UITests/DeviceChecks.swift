import XCTest

/// The checks of the roadmap before 1.0.0: live TV, the player options and keys, Picture in
/// Picture, the next episode, the profile editor, and backup. They need real sources and the
/// network. Run them as `EndToEndTests`, with `TEST_RUNNER_ZS_E2E_SOURCES`. With no sources,
/// they are skipped.
final class DeviceChecks: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard let sources = ProcessInfo.processInfo.environment["ZS_E2E_SOURCES"], !sources.isEmpty else {
            throw XCTSkip("ZS_E2E_SOURCES is not set.")
        }
        app = XCUIApplication()
        app.launch()
        let main = app.buttons["Main"].firstMatch
        if main.waitForExistence(timeout: 15) { main.tap() }
        wait(app.tabBars.firstMatch, 10, "The tabs")
        try addSources(sources)
    }

    /// Adds the sources one time. A later test finds them on the device.
    private func addSources(_ sources: String) throws {
        app.tabBars.buttons["Settings"].tap()
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Sources'")).firstMatch
        wait(row, 10, "The Sources row")
        guard row.label.contains("0 sources") else { return }
        row.tap()
        let editor = app.textViews.firstMatch
        wait(editor, 10, "The source editor")
        editor.tap()
        editor.typeText(sources)
        app.buttons["Save"].tap()
        app.navigationBars.buttons.firstMatch.tap()
    }

    private func wait(_ element: XCUIElement, _ seconds: TimeInterval, _ what: String) {
        XCTAssertTrue(element.waitForExistence(timeout: seconds), "\(what) does not show.")
    }

    private func shot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var player: XCUIElement { app.otherElements["player"] }

    /// Shows the controls of the player. A tap on the video shows them, or hides them.
    private func showControls() {
        if !app.buttons["Options"].exists { player.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap() }
        wait(app.buttons["Options"], 5, "The controls of the player")
    }

    /// Waits until the video plays: the time slider shows only with a known length.
    /// The player can try several streams first.
    private func waitUntilPlaying(_ seconds: TimeInterval = 180) {
        wait(player, 120, "The player")
        let end = Date().addingTimeInterval(seconds)
        while Date() < end {
            if !app.sliders.firstMatch.exists { player.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap() }
            if app.sliders.firstMatch.waitForExistence(timeout: 3) { return }
            sleep(5)
        }
        XCTFail("The video does not play.")
    }

    /// The controls hide after a few seconds. On a slow machine they can hide before the tap,
    /// so this shows them again until the Close button is there.
    private func closePlayer() {
        let close = app.buttons["Close"]
        for _ in 0..<3 where !close.isHittable {
            player.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
            _ = close.waitForExistence(timeout: 3)
        }
        close.tap()
        XCTAssertTrue(player.waitForNonExistence(timeout: 10), "The player does not close.")
    }

    func testLiveTvShowsTheChannelsAndPlaysOne() {
        app.tabBars.buttons["Live TV"].tap()
        // The playlists and the guides load first. A query while they load can time out on a slow machine.
        sleep(20)
        let channel = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'channel:'")).firstMatch
        wait(channel, 120, "A channel")
        sleep(5)
        shot("live")
        channel.tap()
        wait(player, 30, "The player of a channel")
        sleep(10)
        shot("live-player")
        XCTAssertEqual(app.state, .runningForeground)
        closePlayer()
    }

    func testThePlayerOptionsKeysAndPictureInPicture() {
        app.tabBars.buttons["Home"].tap()
        let poster = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card:'")).firstMatch
        wait(poster, 90, "A poster on Home")
        poster.tap()
        let play = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Watch' OR label BEGINSWITH 'Resume'")).firstMatch
        wait(play, 30, "The Play button")
        play.tap()
        waitUntilPlaying()

        showControls()
        app.buttons["Options"].tap()
        wait(app.staticTexts["Subtitle delay"], 5, "The options")
        shot("options")
        XCTAssertTrue(app.staticTexts["Subtitle size"].exists)
        app.buttons["Done"].tap()

        // A key of the keyboard reaches the player: the number 5 goes to the middle of the video.
        app.typeKey("5", modifierFlags: [])
        wait(app.staticTexts["50%"], 5, "The message of the number key")
        shot("number-key")

        showControls()
        let pip = app.buttons["Picture in Picture"]
        // The button shows only when the stream can play in a small window.
        if pip.exists && pip.isEnabled {
            pip.tap()
            sleep(3)
            shot("picture-in-picture")
            app.activate()
            sleep(2)
        }
        XCTAssertEqual(app.state, .runningForeground)

        // The Escape of XCUITest does not reach the app in the simulator, while the other keys
        // do, so the player closes with its button here. See docs/decisions.md.
        closePlayer()
    }

    func testTheNextEpisodeCountdownShowsNearTheEnd() {
        app.tabBars.buttons["Search"].tap()
        let field = app.textFields.firstMatch
        wait(field, 5, "The search field")
        field.tap()
        field.typeText("Breaking Bad\n")
        let card = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card:tt'")).firstMatch
        wait(card, 60, "A result")
        card.tap()
        let play = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Watch S' OR label BEGINSWITH 'Resume S'")).firstMatch
        wait(play, 30, "The Play button of an episode")
        play.tap()
        waitUntilPlaying()

        // 9 goes to 90 percent. Then L goes 10 seconds on at each press, up to the countdown.
        // The keys give the same seeks as the viewer, and a torrent loads each part.
        app.typeKey("9", modifierFlags: [])
        let countdown = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Next episode in'")).firstMatch
        for _ in 0..<60 where !countdown.exists {
            app.typeKey("l", modifierFlags: [])
            sleep(2)
        }
        wait(countdown, 60, "The countdown to the next episode")
        shot("countdown")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(countdown.waitForNonExistence(timeout: 5))
        closePlayer()
    }

    func testTheProfileEditorShowsPicturesAndSavesAName() {
        app.tabBars.buttons["Settings"].tap()
        app.staticTexts["Switch profile"].tap()
        wait(app.buttons["Edit profiles"], 10, "Edit profiles")
        app.buttons["Edit profiles"].tap()
        app.buttons["Edit Main"].firstMatch.tap()
        let avatar = app.buttons["avatar"].firstMatch
        wait(avatar, 60, "A profile picture")
        shot("pictures")
        let name = app.textFields.firstMatch
        name.tap()
        name.typeText("s")
        avatar.tap()
        app.buttons["Save"].tap()
        wait(app.buttons["Edit Mains"].firstMatch, 10, "The new name")
        // The name goes back, so that the next run finds the profile.
        app.buttons["Edit Mains"].firstMatch.tap()
        let field = app.textFields.firstMatch
        wait(field, 10, "The name field")
        field.tap()
        field.typeText(XCUIKeyboardKey.delete.rawValue)
        app.buttons["No picture"].tap()
        app.buttons["Save"].tap()
        wait(app.buttons["Edit Main"].firstMatch, 10, "The first name")
    }

    func testBackUpOpensTheFileExporter() {
        app.tabBars.buttons["Settings"].tap()
        let backUp = app.staticTexts["Back up"]
        for _ in 0..<6 where !backUp.isHittable { app.swipeUp() }
        backUp.tap()
        // The system sheet asks where to keep the file.
        // iOS 27 shows the exporter in the app with "DOCPicker" names. An older iOS can name its
        // buttons Save, Move, or Cancel, or show it from a system process.
        let names = "identifier BEGINSWITH 'DOC' OR label IN {'Save', 'Move', 'Cancel'}"
        let system = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        var shown = false
        let end = Date().addingTimeInterval(60)
        while !shown && Date() < end {
            shown = app.buttons.matching(NSPredicate(format: names)).firstMatch.exists
                || system.buttons.matching(NSPredicate(format: names)).firstMatch.exists
            if !shown { usleep(500_000) }
        }
        XCTAssertTrue(shown, "The file exporter does not show.")
        shot("backup")
        app.swipeDown(velocity: .fast)
        sleep(2)
        XCTAssertEqual(app.state, .runningForeground)
    }
}
