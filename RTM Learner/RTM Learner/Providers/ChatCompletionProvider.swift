import Foundation

enum LLMProviderError: Error {
    case httpError(statusCode: Int)
    case invalidResponse
    case emptyContent
}

struct ChatCompletionProvider: LLMProvider {
    let baseURL: String
    let apiKey: String
    let model: String
    let extraHeaders: [String: String]
    let http: HTTPClient

    init(baseURL: String, apiKey: String, model: String,
         extraHeaders: [String: String] = [:],
         http: HTTPClient = URLSession.shared) {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.extraHeaders = extraHeaders
        self.http = http
    }

    func complete(prompt: String) async throws -> String {
        let url = URL(string: "\(baseURL)/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        for (key, value) in extraHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let body: [String: Any] = [
            "model": model,
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
            struct Choice: Decodable {
                struct Message: Decodable { let content: String }
                let message: Message
            }
            let choices: [Choice]
        }
        let parsed = try JSONDecoder().decode(Response.self, from: data)
        guard let content = parsed.choices.first?.message.content else {
            throw LLMProviderError.emptyContent
        }
        return content
    }
}
