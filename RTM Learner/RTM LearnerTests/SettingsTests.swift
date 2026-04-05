import XCTest
import Observation
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

    // MARK: - Observation tracking
    //
    // These tests catch the class of bug where @Observable is used with computed properties
    // backed by external storage (e.g. UserDefaults). @Observable only instruments *stored*
    // properties with access/withMutation tracking. If any Settings property is ever changed
    // back to a computed property, these tests will fail — meaning SwiftUI views that read
    // those properties will silently stop re-rendering on mutation.

    func test_schedule_mutation_notifiesObservers() {
        var changed = false
        withObservationTracking {
            _ = settings.schedule
        } onChange: {
            changed = true
        }

        settings.schedule = ScheduleConfig(days: [.friday], hour: 10, minute: 0)

        XCTAssertTrue(changed,
            "Mutating schedule must trigger @Observable notification. " +
            "If this fails, schedule is a computed property and SwiftUI views won't re-render.")
    }

    func test_providerType_mutation_notifiesObservers() {
        var changed = false
        withObservationTracking {
            _ = settings.providerType
        } onChange: {
            changed = true
        }

        settings.providerType = .gemini

        XCTAssertTrue(changed,
            "Mutating providerType must trigger @Observable notification.")
    }

    func test_claudeModel_mutation_notifiesObservers() {
        var changed = false
        withObservationTracking {
            _ = settings.claudeModel
        } onChange: {
            changed = true
        }

        settings.claudeModel = "claude-haiku-4-5-20251001"

        XCTAssertTrue(changed,
            "Mutating claudeModel must trigger @Observable notification.")
    }

    // MARK: - Cross-instance persistence
    //
    // These tests verify that didSet actually writes to UserDefaults. A fresh Settings
    // instance loaded from the same suite must see mutations made by the previous instance.
    // The round-trip tests above (same instance) would pass even if didSet were missing;
    // these tests would not.

    func test_schedule_mutation_persistsToUserDefaults() {
        let config = ScheduleConfig(days: [.saturday], hour: 11, minute: 30)
        settings.schedule = config

        let reloaded = Settings(suiteName: suiteName)
        XCTAssertEqual(reloaded.schedule, config,
            "Schedule must be persisted via didSet so a new instance loads the updated value.")
    }

    func test_providerType_mutation_persistsToUserDefaults() {
        settings.providerType = .openai

        let reloaded = Settings(suiteName: suiteName)
        XCTAssertEqual(reloaded.providerType, .openai,
            "providerType must be persisted via didSet.")
    }

    func test_claudeModel_mutation_persistsToUserDefaults() {
        settings.claudeModel = "claude-haiku-4-5-20251001"

        let reloaded = Settings(suiteName: suiteName)
        XCTAssertEqual(reloaded.claudeModel, "claude-haiku-4-5-20251001",
            "claudeModel must be persisted via didSet.")
    }
}
