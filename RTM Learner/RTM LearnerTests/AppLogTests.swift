import XCTest
import Observation
@testable import RTM_Learner

final class AppLogTests: XCTestCase {

    func test_isPipelineRunning_defaultsToFalse() {
        let log = AppLog()
        XCTAssertFalse(log.isPipelineRunning)
    }

    func test_isPipelineRunning_canBeSetTrue() {
        let log = AppLog()
        log.isPipelineRunning = true
        XCTAssertTrue(log.isPipelineRunning)
    }

    func test_isPipelineRunning_isObserved() {
        let log = AppLog()
        var observed = false
        withObservationTracking {
            _ = log.isPipelineRunning
        } onChange: {
            observed = true
        }
        log.isPipelineRunning = true
        XCTAssertTrue(observed, "isPipelineRunning change must trigger observation")
    }

    func test_append_addsTImestampedLine() {
        let log = AppLog()
        log.append("hello")
        XCTAssertTrue(log.text.contains("hello"))
        XCTAssertTrue(log.text.contains("["), "Should contain timestamp bracket")
    }

    func test_clear_emptiesText() {
        let log = AppLog()
        log.append("hello")
        log.clear()
        XCTAssertEqual(log.text, "")
    }
}
