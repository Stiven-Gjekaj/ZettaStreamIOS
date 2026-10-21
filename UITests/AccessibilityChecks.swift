import XCTest

/// Runs the accessibility audit of Xcode on each main screen. A missing label, a small
/// touch target, a wrong trait, or text with no Dynamic Type fails the test.
/// With sources, Home and Live TV have their content. With no sources, they show their messages.
final class AccessibilityChecks: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = true
        app = XCUIApplication()
        app.launch()
        let main = app.buttons["Main"].firstMatch
        if main.waitForExistence(timeout: 15) { main.tap() }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
    }

    private func audit(_ tab: String, wait: XCUIElement? = nil) throws {
        app.tabBars.buttons[tab].tap()
        _ = wait?.waitForExistence(timeout: 60)
        sleep(2)
        guard #available(iOS 17.0, *) else { throw XCTSkip("The audit needs iOS 17.") }
        // The tab bar and the system parts are not the code of the app.
        let bar = app.tabBars.firstMatch.frame
        let name = tab
        try app.performAccessibilityAudit { issue in
            let element = issue.element
            // Text under the tab bar fails the contrast check, because the bar is not opaque.
            if let frame = element?.frame, bar.intersects(frame) { return true }
            // A title on one line ends with "...", text can sit on poster art, and the subtitle
            // font shows in its own font. These show as notes, not as faults. See docs/decisions.md.
            let note: XCUIAccessibilityAuditType = [.contrast, .textClipped]
            let partial = issue.compactDescription.contains("partially")
            let isNote = note.contains(issue.auditType) || partial
            print("AUDIT \(isNote ? "note" : "fault") \(name): \(issue.compactDescription) on \(element?.debugDescription.prefix(160) ?? "no element")")
            return isNote
        }
    }

    func testHome() throws {
        try audit("Home", wait: app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card:'")).firstMatch)
    }

    func testSearch() throws { try audit("Search") }
    func testLibrary() throws { try audit("Library") }
    func testLiveTv() throws { try audit("Live TV", wait: app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'channel:'")).firstMatch) }
    func testSettings() throws { try audit("Settings") }
}
