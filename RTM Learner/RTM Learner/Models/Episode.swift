import Foundation

struct Episode: Codable {
    var episode: Int
    var title: String
    var url: String
    var pubDate: String
    var textSimplified: String
    var textTraditional: String
    var words: [Word]
    var idioms: [Word]
    var dialogue: [DialogueLine]
    var grammar: [GrammarPattern]
    var exercises: [Exercise]

    enum CodingKeys: String, CodingKey {
        case episode, title, url
        case pubDate        = "pub_date"
        case textSimplified = "text_simplified"
        case textTraditional = "text_traditional"
        case words, idioms, dialogue, grammar, exercises
    }
}

extension Episode {
    /// Custom decoder so the Parser can decode LLM responses that omit metadata
    /// fields (episode, title, url, pubDate). The pipeline merges them in afterward.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        episode        = try c.decodeIfPresent(Int.self,    forKey: .episode) ?? 0
        title          = try c.decodeIfPresent(String.self, forKey: .title)   ?? ""
        url            = try c.decodeIfPresent(String.self, forKey: .url)     ?? ""
        pubDate        = try c.decodeIfPresent(String.self, forKey: .pubDate) ?? ""
        textSimplified = try c.decode(String.self, forKey: .textSimplified)
        textTraditional = try c.decode(String.self, forKey: .textTraditional)
        words          = try c.decodeIfPresent([Word].self,          forKey: .words)     ?? []
        idioms         = try c.decodeIfPresent([Word].self,          forKey: .idioms)    ?? []
        dialogue       = try c.decodeIfPresent([DialogueLine].self,  forKey: .dialogue)  ?? []
        grammar        = try c.decodeIfPresent([GrammarPattern].self, forKey: .grammar)  ?? []
        exercises      = try c.decodeIfPresent([Exercise].self,      forKey: .exercises) ?? []
    }
}

struct Word: Codable {
    var type: String
    var number: Int
    var chinese: String
    var pinyin: String
    var english: String
    var exampleZh: String
    var exampleEn: String
    var german: String
    var exampleDe: String

    enum CodingKeys: String, CodingKey {
        case type, number, chinese, pinyin, english
        case exampleZh = "example_zh"
        case exampleEn = "example_en"
        case german
        case exampleDe = "example_de"
    }

    init(type: String, number: Int, chinese: String, pinyin: String,
         english: String, exampleZh: String, exampleEn: String,
         german: String = "", exampleDe: String = "") {
        self.type = type; self.number = number; self.chinese = chinese
        self.pinyin = pinyin; self.english = english
        self.exampleZh = exampleZh; self.exampleEn = exampleEn
        self.german = german; self.exampleDe = exampleDe
    }
}

struct DialogueLine: Codable {
    var speaker: String
    var line: String
}

struct GrammarPattern: Codable {
    var pattern: String
    var pinyin: String
    var meaningEn: String
    var examplesZh: [String]

    enum CodingKeys: String, CodingKey {
        case pattern, pinyin
        case meaningEn   = "meaning_en"
        case examplesZh  = "examples_zh"
    }
}

struct Exercise: Codable {
    var question: String
    var options: [String]
    var answerIndex: Int
    var answerText: String

    enum CodingKeys: String, CodingKey {
        case question, options
        case answerIndex = "answer_index"
        case answerText  = "answer_text"
    }
}
