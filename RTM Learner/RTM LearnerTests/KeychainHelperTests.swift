import XCTest
@testable import RTM_Learner

final class KeychainHelperTests: XCTestCase {

    private let testKey = "com.rtm-learner.test.\(UUID().uuidString)"

    override func tearDown() {
        try? KeychainHelper.delete(for: testKey)
        super.tearDown()
    }

    func test_saveAndLoad_roundTrips() throws {
        try KeychainHelper.save("secret-value", for: testKey)
        let loaded = try KeychainHelper.load(for: testKey)
        XCTAssertEqual(loaded, "secret-value")
    }

    func test_load_throwsNotFoundWhenMissing() {
        XCTAssertThrowsError(try KeychainHelper.load(for: testKey)) { error in
            XCTAssertEqual(error as? KeychainError, .notFound)
        }
    }

    func test_save_overwritesExistingValue() throws {
        try KeychainHelper.save("first", for: testKey)
        try KeychainHelper.save("second", for: testKey)
        let loaded = try KeychainHelper.load(for: testKey)
        XCTAssertEqual(loaded, "second")
    }

    func test_delete_removesValue() throws {
        try KeychainHelper.save("value", for: testKey)
        try KeychainHelper.delete(for: testKey)
        XCTAssertThrowsError(try KeychainHelper.load(for: testKey))
    }

    func test_delete_succeedsWhenKeyMissing() {
        XCTAssertNoThrow(try KeychainHelper.delete(for: testKey))
    }
}
