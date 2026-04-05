import XCTest
@testable import RTM_Learner

final class TranslatorTests: XCTestCase {

    func test_translate_returnsUnchangedWhenNoWordsOrIdioms() async throws {
        let mock = MockLLMProvider()
        var episode = makeEpisode(words: [], idioms: [])
        try await Translator.translate(episode: &episode, provider: mock)
        XCTAssertEqual(mock.callCount, 0)
    }

    func test_translate_addsGermanAndExampleDe() async throws {
        let mock = MockLLMProvider()
        mock.response = """
        [{"german":"Test","example_de":"Das ist ein Test"}]
        """
        var episode = makeEpisode(
            words: [Word(type:"priority",number:1,chinese:"测试",pinyin:"cè shì",
                        english:"test",exampleZh:"例子",exampleEn:"example")],
            idioms: []
        )
        try await Translator.translate(episode: &episode, provider: mock)
        XCTAssertEqual(episode.words[0].german, "Test")
        XCTAssertEqual(episode.words[0].exampleDe, "Das ist ein Test")
    }

    func test_translate_includesTopicInPrompt() async throws {
        let mock = MockLLMProvider()
        mock.response = "[{\"german\":\"x\",\"example_de\":\"x\"}]"
        var episode = makeEpisode(
            words: [Word(type:"priority",number:1,chinese:"测试",pinyin:"cè shì",
                        english:"test",exampleZh:"",exampleEn:"")],
            idioms: []
        )
        episode.title = "AI and Technology"
        try await Translator.translate(episode: &episode, provider: mock)
        XCTAssertTrue(mock.lastPrompt.contains("AI and Technology"))
    }

    func test_translate_separatesWordsAndIdioms() async throws {
        let mock = MockLLMProvider()
        mock.response = """
        [{"german":"Test","example_de":""},{"german":"einwandfrei","example_de":""}]
        """
        var episode = makeEpisode(
            words: [Word(type:"priority",number:1,chinese:"测试",pinyin:"",english:"test",exampleZh:"",exampleEn:"")],
            idioms: [Word(type:"idiom",number:1,chinese:"无懈可击",pinyin:"",english:"flawless",exampleZh:"",exampleEn:"")]
        )
        try await Translator.translate(episode: &episode, provider: mock)
        XCTAssertEqual(episode.words[0].german, "Test")
        XCTAssertEqual(episode.idioms[0].german, "einwandfrei")
    }

    // MARK: - Helper

    private func makeEpisode(words: [Word], idioms: [Word]) -> Episode {
        Episode(episode: 1, title: "Test", url: "https://x.com", pubDate: "2024-01-01",
                textSimplified: "", textTraditional: "",
                words: words, idioms: idioms, dialogue: [], grammar: [], exercises: [])
    }
}
