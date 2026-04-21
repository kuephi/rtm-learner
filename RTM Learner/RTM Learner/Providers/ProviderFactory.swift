import Foundation

enum ProviderFactory {
    /// Build the active LLMProvider from current settings + Keychain.
    /// Throws KeychainError.notFound if the required API key is missing.
    static func make(settings: Settings, http: HTTPClient = URLSession.shared) throws -> LLMProvider {
        switch settings.providerType {
        case .claude:
            let key = try KeychainHelper.load(for: "claude_api_key")
            return ClaudeProvider(apiKey: key, model: settings.activeModel(), http: http)
        case .gemini:
            let key = try KeychainHelper.load(for: "gemini_api_key")
            return GeminiProvider(apiKey: key, model: settings.activeModel(), http: http)
        case .openai:
            let key = try KeychainHelper.load(for: "openai_api_key")
            return OpenAIProvider(apiKey: key, model: settings.activeModel(), http: http)
        case .openrouter:
            let key = try KeychainHelper.load(for: "openrouter_api_key")
            return OpenRouterProvider(apiKey: key, model: settings.activeModel(), http: http)
        }
    }
}
