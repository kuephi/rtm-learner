import Foundation

struct Translator {
    private static let promptTemplate = """
    You are a Chinese-to-German language expert helping a German speaker learn Mandarin.

    For each word/idiom in the JSON array below, add two fields:
    - "german": a concise, natural German definition
    - "example_de": a natural German translation of the Chinese example sentence

    The words appear in a text about: {topic}
    Use this context to choose the most fitting German meaning where ambiguous.

    Input JSON array:
    {words}

    Return ONLY a JSON array (same length, same order) with the added fields.
    No markdown, no explanation.
    """

    /// Adds `german` and `example_de` to all words and idioms in the episode in-place.
    static func translate(episode: inout Episode, provider: LLMProvider) async throws {
        let all = episode.words + episode.idioms
        guard !all.isEmpty else { return }

        let payload = all.map { w in
            ["chinese": w.chinese, "pinyin": w.pinyin, "english": w.english,
             "example_zh": w.exampleZh, "example_en": w.exampleEn]
        }
        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: .prettyPrinted)
        let payloadString = String(data: payloadData, encoding: .utf8) ?? "[]"

        let prompt = promptTemplate
            .replacingOccurrences(of: "{topic}", with: episode.title)
            .replacingOccurrences(of: "{words}", with: payloadString)

        let raw = try await provider.complete(prompt: prompt)
        guard let data = JSONRepair.repair(raw) else { return }

        struct TranslationResult: Decodable {
            let german: String?
            let exampleDe: String?
            enum CodingKeys: String, CodingKey {
                case german; case exampleDe = "example_de"
            }
        }
        guard let results = try? JSONDecoder().decode([TranslationResult].self, from: data) else { return }

        let n = episode.words.count
        for (i, result) in results.prefix(all.count).enumerated() {
            if i < n {
                episode.words[i].german    = result.german    ?? ""
                episode.words[i].exampleDe = result.exampleDe ?? ""
            } else {
                episode.idioms[i - n].german    = result.german    ?? ""
                episode.idioms[i - n].exampleDe = result.exampleDe ?? ""
            }
        }
    }
}
