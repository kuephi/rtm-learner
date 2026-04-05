import XCTest
@testable import RTM_Learner

final class ModelTests: XCTestCase {

    // MARK: - ScheduleConfig

    func test_scheduleConfig_encodesAndDecodes() throws {
        let config = ScheduleConfig(days: [.monday, .friday], hour: 8, minute: 30)
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(ScheduleConfig.self, from: data)
        XCTAssertEqual(decoded.days, [.monday, .friday])
        XCTAssertEqual(decoded.hour, 8)
        XCTAssertEqual(decoded.minute, 30)
    }

    func test_weekday_rawValues_matchCalendar() {
        // Calendar.current.component(.weekday) uses 1=Sun, 2=Mon … 7=Sat
        XCTAssertEqual(Weekday.sunday.rawValue, 1)
        XCTAssertEqual(Weekday.monday.rawValue, 2)
        XCTAssertEqual(Weekday.saturday.rawValue, 7)
    }

    func test_scheduleConfig_defaultConfig_isValid() {
        let config = ScheduleConfig.defaultConfig
        XCTAssertFalse(config.days.isEmpty)
        XCTAssertTrue((0...23).contains(config.hour))
        XCTAssertTrue((0...59).contains(config.minute))
    }

    // MARK: - Episode

    func test_word_encodesAndDecodes() throws {
        let word = Word(
            type: "priority", number: 1,
            chinese: "测试", pinyin: "cè shì",
            english: "test",
            exampleZh: "这是测试", exampleEn: "This is a test"
        )
        let data = try JSONEncoder().encode(word)
        let decoded = try JSONDecoder().decode(Word.self, from: data)
        XCTAssertEqual(decoded.chinese, "测试")
        XCTAssertEqual(decoded.german, "")
        XCTAssertEqual(decoded.exampleDe, "")
    }

    func test_episode_decodesFromPythonJSON() throws {
        // Matches the schema produced by the Python pipeline
        let json = """
        {
          "episode": 265,
          "title": "#265[中级]: Test",
          "url": "https://example.com",
          "pub_date": "2024-01-01",
          "text_simplified": "文章",
          "text_traditional": "文章",
          "words": [],
          "idioms": [],
          "dialogue": [],
          "grammar": [],
          "exercises": []
        }
        """.data(using: .utf8)!
        let episode = try JSONDecoder().decode(Episode.self, from: json)
        XCTAssertEqual(episode.episode, 265)
        XCTAssertEqual(episode.textSimplified, "文章")
    }

    func test_episode_encodesWithSnakeCaseKeys() throws {
        let episode = Episode(
            episode: 1, title: "Test", url: "https://x.com", pubDate: "2024-01-01",
            textSimplified: "简体", textTraditional: "繁體",
            words: [], idioms: [], dialogue: [], grammar: [], exercises: []
        )
        let data = try JSONEncoder().encode(episode)
        let dict = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        XCTAssertNotNil(dict["text_simplified"])
        XCTAssertNotNil(dict["pub_date"])
    }

    // MARK: - LLMProviderType

    func test_llmProviderType_defaultModels() {
        XCTAssertEqual(LLMProviderType.claude.defaultModel, "claude-sonnet-4-6")
        XCTAssertEqual(LLMProviderType.gemini.defaultModel, "gemini-2.0-flash")
        XCTAssertEqual(LLMProviderType.openai.defaultModel, "gpt-4o")
        XCTAssertNil(LLMProviderType.openrouter.defaultModel)
    }

    func test_llmProviderType_encodesAndDecodes() throws {
        let data = try JSONEncoder().encode(LLMProviderType.claude)
        let decoded = try JSONDecoder().decode(LLMProviderType.self, from: data)
        XCTAssertEqual(decoded, .claude)
    }
}
