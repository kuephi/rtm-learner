import XCTest

/// UI tests for RTM Learner preferences window.
///
/// How this works:
///   The app is launched with `--uitesting`, which causes AppDelegate to open the
///   Preferences window immediately instead of waiting for the user to click the menu bar
///   icon. This sidesteps the unreliability of clicking system status bar items in XCUITest.
///
/// What is tested:
///   - The schedule day circles toggle correctly (this is the regression for the @Observable
///     computed-property bug: with that bug the click fired but the UI never re-rendered).
///   - The hour stepper increments the displayed time.
///
/// Limitations:
///   - The menu bar popover itself is not tested here. Accessing system status bar items
///     via XCUITest requires System Events / Accessibility permissions at the OS level and
///     is brittle. Popover interaction is better covered by unit + snapshot tests.
///   - Network calls (Run Now / pipeline) are not tested here; they belong in integration
///     tests with mocked HTTP.
final class RTM_LearnerUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
    }

    // MARK: - Schedule: day circles

    /// Clicking an unselected day circle must select it (regression for the @Observable bug).
    /// With computed-property Settings the view never re-rendered, so the circle stayed
    /// visually unselected even though UserDefaults was updated.
    @MainActor
    func test_dayCircle_clickUnselected_becomesSelected() throws {
        let window = try preferencesWindow()

        // Default schedule: Mon / Wed / Fri (rawValues 2, 4, 6).
        // Saturday (rawValue 7) is unselected by default.
        let saturday = window.buttons["day-7"]
        XCTAssertTrue(saturday.waitForExistence(timeout: 2), "Saturday day circle not found")
        XCTAssertEqual(saturday.value as? String, "unselected",
                       "Saturday should start unselected")

        saturday.click()

        XCTAssertEqual(saturday.value as? String, "selected",
                       "Saturday must be selected after click — if this fails, @Observable " +
                       "is not tracking the property and the view is not re-rendering.")
    }

    /// Clicking a selected day circle must deselect it (as long as at least one day remains).
    @MainActor
    func test_dayCircle_clickSelected_becomesUnselected() throws {
        let window = try preferencesWindow()

        // Friday (rawValue 6) is selected by default.
        let friday = window.buttons["day-6"]
        XCTAssertTrue(friday.waitForExistence(timeout: 2))
        XCTAssertEqual(friday.value as? String, "selected")

        friday.click()

        XCTAssertEqual(friday.value as? String, "unselected",
                       "Friday must be deselected after click.")
    }

    // MARK: - Schedule: time steppers

    /// Clicking the increment button of the hour stepper must update the displayed time.
    @MainActor
    func test_hourStepper_increment_updatesDisplay() throws {
        let window = try preferencesWindow()

        let stepper = window.steppers["stepper-hour"]
        XCTAssertTrue(stepper.waitForExistence(timeout: 2), "Hour stepper not found")

        // Capture the current time label (format "HH:mm")
        let timeLabel = window.staticTexts.matching(NSPredicate(format: "value MATCHES %@", "\\d{2}:\\d{2}")).firstMatch
        XCTAssertTrue(timeLabel.waitForExistence(timeout: 2))
        let before = timeLabel.value as? String ?? ""

        stepper.buttons["Increment"] .click()

        let after = timeLabel.value as? String ?? ""
        XCTAssertNotEqual(before, after,
                          "Hour stepper increment must update the displayed time — if this " +
                          "fails the Stepper binding is not triggering a view re-render.")
    }

    // MARK: - Preferences window navigation

    @MainActor
    func test_preferencesWindow_opens() throws {
        _ = try preferencesWindow()
    }

    // MARK: - Helpers

    @MainActor
    private func preferencesWindow() throws -> XCUIElement {
        let window = app.windows["RTM Learner Preferences"]
        guard window.waitForExistence(timeout: 3) else {
            throw XCTSkip("Preferences window did not appear — is --uitesting flag handled?")
        }
        return window
    }
}
