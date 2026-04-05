import Foundation

enum ParserError: Error {
    case decodingFailed(String)
}

struct Parser {
    private static let prompt = """
    You are a structured data extractor for RTM Mandarin Chinese lessons.
    Extract ALL content from the lesson text below into the exact JSON structure shown.
    Return ONLY valid JSON — no markdown fences, no commentary.

    JSON schema:
    {
      "text_simplified": "the main simplified Chinese article text",
      "text_traditional": "the traditional Chinese version of the same text",
      "words": [{"type":"priority","number":1,"chinese":"内测","pinyin":"nèi cè",
        "english":"internal testing","example_zh":"","example_en":"","german":"","example_de":""}],
      "idioms": [{"type":"idiom","number":1,"chinese":"无懈可击","pinyin":"wú xiè kě jī",
        "english":"flawless","example_zh":"","example_en":"","german":"","example_de":""}],
      "dialogue": [{"speaker":"老李","line":"Chinese line"}],
      "grammar": [{"pattern":"立马 + verb","pinyin":"lì mǎ","meaning_en":"immediately",
        "examples_zh":["example 1","example 2"]}],
      "exercises": [{"question":"question with ___","options":["a","b","c","d"],
        "answer_index":1,"answer_text":"correct"}]
    }

    Lesson text:
    """

    static func parse(
        text: String,
        entry: FeedEntry,
        provider: LLMProvider
    ) async throws -> Episode {
        let raw = try await provider.complete(prompt: prompt + text)
        guard let data = JSONRepair.repair(raw) else {
            throw ParserError.decodingFailed("JSON repair failed")
        }
        var episode = try JSONDecoder().decode(Episode.self, from: data)
        // Merge feed metadata
        episode.episode = entry.episode
        episode.title   = entry.title
        episode.url     = entry.url
        episode.pubDate = entry.pubDate
        return episode
    }
}
