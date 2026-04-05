import XCTest
@testable import RTM_Learner

final class StateManagerTests: XCTestCase {

    var manager: StateManager!
    var tempDir: URL!

    override func setUp() async throws {
        try await super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        manager = await StateManager(directory: tempDir)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: tempDir)
        try await super.tearDown()
    }

    func test_newManager_hasNoProcessedURLs() async {
        let processed = await manager.isProcessed(url: "https://example.com")
        XCTAssertFalse(processed)
    }

    func test_markProcessed_makesURLProcessed() async throws {
        try await manager.markProcessed(url: "https://example.com/1")
        let processed = await manager.isProcessed(url: "https://example.com/1")
        XCTAssertTrue(processed)
    }

    func test_markProcessed_doesNotAffectOtherURLs() async throws {
        try await manager.markProcessed(url: "https://example.com/1")
        let other = await manager.isProcessed(url: "https://example.com/2")
        XCTAssertFalse(other)
    }

    func test_state_persistsAcrossInstances() async throws {
        try await manager.markProcessed(url: "https://example.com/1")
        let manager2 = await StateManager(directory: tempDir)
        let processed = await manager2.isProcessed(url: "https://example.com/1")
        XCTAssertTrue(processed)
    }

    func test_lastRunDate_isNilInitially() async {
        let date = await manager.lastRunDate
        XCTAssertNil(date)
    }

    func test_setLastRunDate_persistsAcrossInstances() async throws {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        try await manager.setLastRunDate(date)
        let manager2 = await StateManager(directory: tempDir)
        let loaded = await manager2.lastRunDate
        XCTAssertEqual(loaded?.timeIntervalSince1970 ?? 0, date.timeIntervalSince1970, accuracy: 1)
    }
}
