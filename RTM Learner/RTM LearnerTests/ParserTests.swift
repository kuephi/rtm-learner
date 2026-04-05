import XCTest
@testable import RTM_Learner

final class ParserTests: XCTestCase {

    let sampleEpisodeJSON = """
    {
      "text_simplified": "文章内容",
      "text_traditional": "文章內容",
      "words": [{"type":"priority","number":1,"chinese":"测试","pinyin":"cè shì",
                 "english":"test","example_zh":"例子","example_en":"example",
                 "german":"","example_de":""}],
      "idioms": [],
      "dialogue": [],
      "grammar": [],
      "exercises": []
    }
    """

    func test_parse_callsProviderWithLessonText() async throws {
        let mock = MockLLMProvider()
        mock.response = sampleEpisodeJSON

        let meta = FeedEntry(episode: 265, title: "Test", url: "https://x.com", pubDate: "2024-01-01")
        _ = try await Parser.parse(text: "lesson content here", entry: meta, provider: mock)

        XCTAssertTrue(mock.lastPrompt.contains("lesson content here"))
        XCTAssertEqual(mock.callCount, 1)
    }

    func test_parse_mergesMetaIntoEpisode() async throws {
        let mock = MockLLMProvider()
        mock.response = sampleEpisodeJSON

        let meta = FeedEntry(episode: 265, title: "#265[中级]: Topic", url: "https://x.com", pubDate: "2024-01-01")
        let episode = try await Parser.parse(text: "text", entry: meta, provider: mock)

        XCTAssertEqual(episode.episode, 265)
        XCTAssertEqual(episode.title, "#265[中级]: Topic")
        XCTAssertEqual(episode.url, "https://x.com")
    }

    func test_parse_decodesWordsFromResponse() async throws {
        let mock = MockLLMProvider()
        mock.response = sampleEpisodeJSON

        let episode = try await Parser.parse(
            text: "text",
            entry: FeedEntry(episode: 1, title: "T", url: "u", pubDate: "d"),
            provider: mock
        )
        XCTAssertEqual(episode.words.count, 1)
        XCTAssertEqual(episode.words[0].chinese, "测试")
    }

    func test_parse_stripsFenceFromResponse() async throws {
        let mock = MockLLMProvider()
        mock.response = "```json\n\(sampleEpisodeJSON)\n```"

        let episode = try await Parser.parse(
            text: "text",
            entry: FeedEntry(episode: 1, title: "T", url: "u", pubDate: "d"),
            provider: mock
        )
        XCTAssertEqual(episode.textSimplified, "文章内容")
    }
}
