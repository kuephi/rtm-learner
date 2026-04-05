import Foundation

struct GeminiProvider: LLMProvider {
    let apiKey: String
    let model: String
    let http: HTTPClient

    init(apiKey: String, model: String, http: HTTPClient = URLSession.shared) {
        self.apiKey = apiKey; self.model = model; self.http = http
    }

    func complete(prompt: String) async throws -> String {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)"
        let url = URL(string: urlString)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await http.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw LLMProviderError.httpError(statusCode: code)
        }

        struct Response: Decodable {
            struct Candidate: Decodable {
                struct Content: Decodable {
                    struct Part: Decodable { let text: String }
                    let parts: [Part]
                }
                let content: Content
            }
            let candidates: [Candidate]
        }
        let parsed = try JSONDecoder().decode(Response.self, from: data)
        guard let text = parsed.candidates.first?.content.parts.first?.text else {
            throw LLMProviderError.emptyContent
        }
        return text
    }
}
