import XCTest

/// Measures Home: the time from the start of the app to the first poster, and the memory
/// of the app while Home scrolls. Run it after `DeviceChecks`, so that the sources are there.
final class PerformanceChecks: XCTestCase {
    func testHomeShowsItsFirstPosterAndScrolls() throws {
        let app = XCUIApplication()
        let options = XCTMeasureOptions()
        options.iterationCount = 3
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(application: app)], options: options) {
            app.launch()
            let main = app.buttons["Main"].firstMatch
            if main.waitForExistence(timeout: 15) { main.tap() }
            app.tabBars.buttons["Home"].tap()
            let poster = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'card:'")).firstMatch
            XCTAssertTrue(poster.waitForExistence(timeout: 90), "A poster on Home does not show.")
            for _ in 0..<4 { app.swipeUp(velocity: .fast) }
            app.terminate()
        }
    }
}
