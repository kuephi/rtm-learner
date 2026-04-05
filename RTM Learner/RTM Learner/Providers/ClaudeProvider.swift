import Foundation

struct ClaudeProvider: LLMProvider {
    let apiKey: String
    let model: String
    let http: HTTPClient

    init(apiKey: String, model: String, http: HTTPClient = URLSession.shared) {
        self.apiKey = apiKey; self.model = model; self.http = http
    }

    func complete(prompt: String) async throws -> String {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 8192,
            "messages": [["role": "user", "content": prompt]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await http.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw LLMProviderError.httpError(statusCode: code)
        }

        struct Response: Decodable {
            struct Content: Decodable { let type: String; let text: String }
            let content: [Content]
        }
        let parsed = try JSONDecoder().decode(Response.self, from: data)
        guard let text = parsed.content.first(where: { $0.type == "text" })?.text else {
            throw LLMProviderError.emptyContent
        }
        return text
    }
}
