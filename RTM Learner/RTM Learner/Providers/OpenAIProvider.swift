import Foundation

struct OpenAIProvider: LLMProvider {
    private let inner: ChatCompletionProvider

    init(apiKey: String, model: String, http: HTTPClient = URLSession.shared) {
        inner = ChatCompletionProvider(
            baseURL: "https://api.openai.com",
            apiKey: apiKey,
            model: model,
            http: http
        )
    }

    func complete(prompt: String) async throws -> String {
        try await inner.complete(prompt: prompt)
    }
}
