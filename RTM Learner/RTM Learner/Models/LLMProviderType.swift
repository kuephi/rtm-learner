import Foundation

enum LLMProviderType: String, Codable, CaseIterable, Identifiable {
    case claude
    case gemini
    case openai
    case openrouter

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .claude:      return "Claude"
        case .gemini:      return "Gemini"
        case .openai:      return "OpenAI"
        case .openrouter:  return "OpenRouter"
        }
    }

    /// Returns nil for OpenRouter — model is always required there.
    var defaultModel: String? {
        switch self {
        case .claude:      return "claude-sonnet-4-6"
        case .gemini:      return "gemini-2.0-flash"
        case .openai:      return "gpt-4o"
        case .openrouter:  return nil
        }
    }
}
