import XCTest
@testable import RTM_Learner

final class JSONRepairTests: XCTestCase {

    func test_clean_stripsJsonCodeFence() {
        let input = "```json\n{\"key\": \"value\"}\n```"
        XCTAssertEqual(JSONRepair.clean(input), "{\"key\": \"value\"}")
    }

    func test_clean_stripsPlainCodeFence() {
        let input = "```\n{\"key\": \"value\"}\n```"
        XCTAssertEqual(JSONRepair.clean(input), "{\"key\": \"value\"}")
    }

    func test_clean_leavesCleanJSONUnchanged() {
        let input = "{\"key\": \"value\"}"
        XCTAssertEqual(JSONRepair.clean(input), input)
    }

    func test_clean_tripsLeadingTrailingWhitespace() {
        let input = "  {\"key\": \"value\"}  "
        XCTAssertEqual(JSONRepair.clean(input), "{\"key\": \"value\"}")
    }

    func test_repair_parsesValidJSON() {
        let input = "{\"episode\": 1}"
        XCTAssertNotNil(JSONRepair.repair(input))
    }

    func test_repair_fixesTruncatedObject() {
        // Missing closing brace
        let input = "{\"episode\": 1, \"words\": ["
        let data = JSONRepair.repair(input)
        XCTAssertNotNil(data)
        // Should produce parseable JSON
        XCTAssertNotNil(try? JSONSerialization.jsonObject(with: data!))
    }

    func test_repair_stripsFenceBeforeRepairing() {
        let input = "```json\n{\"episode\": 1}\n```"
        XCTAssertNotNil(JSONRepair.repair(input))
    }
}
