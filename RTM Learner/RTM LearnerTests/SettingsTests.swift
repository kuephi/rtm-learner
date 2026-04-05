import XCTest
@testable import RTM_Learner

final class SettingsTests: XCTestCase {

    var settings: Settings!
    let suiteName = "com.rtm-learner.test.\(UUID().uuidString)"

    override func setUp() {
        super.setUp()
        settings = Settings(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func test_defaultSchedule_matchesSpec() {
        XCTAssertEqual(settings.schedule, ScheduleConfig.defaultConfig)
    }

    func test_schedule_roundTrips() {
        let config = ScheduleConfig(days: [.tuesday, .thursday], hour: 9, minute: 15)
        settings.schedule = config
        XCTAssertEqual(settings.schedule, config)
    }

    func test_defaultProvider_isClaude() {
        XCTAssertEqual(settings.providerType, .claude)
    }

    func test_providerType_roundTrips() {
        settings.providerType = .openrouter
        XCTAssertEqual(settings.providerType, .openrouter)
    }

    func test_claudeModel_defaultsToEmpty() {
        XCTAssertEqual(settings.claudeModel, "")
    }

    func test_openRouterModel_roundTrips() {
        settings.openRouterModel = "anthropic/claude-3.5-sonnet"
        XCTAssertEqual(settings.openRouterModel, "anthropic/claude-3.5-sonnet")
    }

    func test_activeModel_returnsDefaultWhenOverrideEmpty() {
        settings.providerType = .claude
        settings.claudeModel = ""
        XCTAssertEqual(settings.activeModel(), "claude-sonnet-4-6")
    }

    func test_activeModel_returnsOverrideWhenSet() {
        settings.providerType = .claude
        settings.claudeModel = "claude-haiku-4-5-20251001"
        XCTAssertEqual(settings.activeModel(), "claude-haiku-4-5-20251001")
    }

    func test_activeModel_openRouterReturnsSelectedModel() {
        settings.providerType = .openrouter
        settings.openRouterModel = "openai/gpt-4o"
        XCTAssertEqual(settings.activeModel(), "openai/gpt-4o")
    }

    func test_lastRunDate_roundTrips() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        settings.lastRunDate = date
        XCTAssertEqual(settings.lastRunDate?.timeIntervalSince1970 ?? 0,
                       date.timeIntervalSince1970, accuracy: 1)
    }
}
