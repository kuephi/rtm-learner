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

    func test_append_writesToLogFile_whenURLProvided() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let logURL = tempDir.appendingPathComponent("test.log")
        let log = AppLog(logFileURL: logURL)
        log.append("persistent message")

        let contents = try String(contentsOf: logURL)
        XCTAssertTrue(contents.contains("persistent message"), "Log file must contain appended message")
    }

    func test_append_appendsAcrossInstances() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let logURL = tempDir.appendingPathComponent("test.log")
        AppLog(logFileURL: logURL).append("first")
        AppLog(logFileURL: logURL).append("second")

        let contents = try String(contentsOf: logURL)
        XCTAssertTrue(contents.contains("first"), "Must contain first entry")
        XCTAssertTrue(contents.contains("second"), "Must contain second entry")
    }

    func test_append_worksWithNilLogFileURL() {
        let log = AppLog()  // default nil
        log.append("no crash")
        XCTAssertTrue(log.text.contains("no crash"))
    }
}
