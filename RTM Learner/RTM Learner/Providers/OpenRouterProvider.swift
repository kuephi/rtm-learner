import Foundation

struct OpenRouterProvider: LLMProvider {
    private let inner: ChatCompletionProvider

    struct Model: Decodable, Identifiable {
        let id: String
        let name: String
    }

    init(apiKey: String, model: String, http: HTTPClient = URLSession.shared) {
        inner = ChatCompletionProvider(
            baseURL: "https://openrouter.ai",
            apiKey: apiKey,
            model: model,
            extraHeaders: ["HTTP-Referer": "https://github.com/kuephi/rtm-learner"],
            http: http
        )
    }

    func complete(prompt: String) async throws -> String {
        try await inner.complete(prompt: prompt)
    }

    /// Fetch the available model list from the OpenRouter API.
    static func fetchModels(
        apiKey: String,
        http: HTTPClient = URLSession.shared
    ) async throws -> [Model] {
        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await http.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw LLMProviderError.httpError(statusCode: code)
        }
        struct Response: Decodable { let data: [Model] }
        return try JSONDecoder().decode(Response.self, from: data).data
    }
}
