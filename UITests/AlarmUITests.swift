import XCTest

final class AlarmUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false

        // Dismiss any system alerts (notification / location permission) automatically
        addUIInterruptionMonitor(withDescription: "System alert") { alert -> Bool in
            let allow = alert.buttons["Allow"]
            let ok    = alert.buttons["OK"]
            if allow.exists { allow.tap(); return true }
            if ok.exists    { ok.tap();    return true }
            return false
        }

        app.launch()
    }

    func testAllowAndAddAlarm() throws {
        // Trigger the interruption monitor by tapping the app
        app.tap()
        sleep(1)
        app.tap()  // second tap in case dialog appeared on first tap
        sleep(1)

        // Find the "Add Alarm" button by its accessibility identifier
        let addBtn = app.buttons["addAlarmButton"]
        XCTAssertTrue(addBtn.waitForExistence(timeout: 6), "Add Alarm button not found")
        addBtn.tap()
        sleep(1)

        // AddAlarmView sheet is now open. Default time (next hour) is pre-filled.
        // Just tap Save to create a quick alarm for today.
        let saveBtn = app.buttons["Save"]
        XCTAssertTrue(saveBtn.waitForExistence(timeout: 4), "Save button not found")
        saveBtn.tap()
        sleep(1)
    }
}
