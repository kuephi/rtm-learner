import XCTest
@testable import RTM_Learner

final class ProviderTests: XCTestCase {

    // MARK: - ChatCompletionProvider

    func test_chatCompletion_sendsCorrectRequestFormat() async throws {
        let mock = MockHTTPClient()
        let responseBody = """
        {"choices":[{"message":{"content":"Hello"}}]}
        """.data(using: .utf8)!
        mock.responses["https://api.test.com/v1/chat/completions"] = (responseBody, 200)

        let provider = ChatCompletionProvider(
            baseURL: "https://api.test.com",
            apiKey: "test-key",
            model: "test-model",
            http: mock
        )
        let result = try await provider.complete(prompt: "Say hello")

        XCTAssertEqual(result, "Hello")
        XCTAssertEqual(mock.requestsMade.count, 1)
        let req = mock.requestsMade[0]
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
        XCTAssertEqual(req.httpMethod, "POST")

        let body = try JSONSerialization.jsonObject(with: req.httpBody!) as! [String: Any]
        XCTAssertEqual(body["model"] as? String, "test-model")
        let messages = body["messages"] as! [[String: String]]
        XCTAssertEqual(messages[0]["role"], "user")
        XCTAssertEqual(messages[0]["content"], "Say hello")
    }

    func test_chatCompletion_throwsOnNon200() async {
        let mock = MockHTTPClient()
        mock.defaultResponse = (Data(), 401)
        let provider = ChatCompletionProvider(
            baseURL: "https://api.test.com",
            apiKey: "bad-key",
            model: "model",
            http: mock
        )
        await XCTAssertThrowsErrorAsync(try await provider.complete(prompt: "x"))
    }

    // MARK: - ClaudeProvider

    func test_claude_sendsAnthropicRequestFormat() async throws {
        let mock = MockHTTPClient()
        let responseBody = """
        {"content":[{"type":"text","text":"你好"}]}
        """.data(using: .utf8)!
        mock.responses["https://api.anthropic.com/v1/messages"] = (responseBody, 200)

        let provider = ClaudeProvider(apiKey: "sk-ant-test", model: "claude-sonnet-4-6", http: mock)
        let result = try await provider.complete(prompt: "Say hello in Chinese")

        XCTAssertEqual(result, "你好")
        let req = mock.requestsMade[0]
        XCTAssertEqual(req.value(forHTTPHeaderField: "x-api-key"), "sk-ant-test")
        XCTAssertEqual(req.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")

        let body = try JSONSerialization.jsonObject(with: req.httpBody!) as! [String: Any]
        XCTAssertEqual(body["model"] as? String, "claude-sonnet-4-6")
        XCTAssertEqual(body["max_tokens"] as? Int, 8192)
    }

    // MARK: - GeminiProvider

    func test_gemini_sendsGoogleRequestFormat() async throws {
        let mock = MockHTTPClient()
        let model = "gemini-2.0-flash"
        let responseBody = """
        {"candidates":[{"content":{"parts":[{"text":"你好"}]}}]}
        """.data(using: .utf8)!
        let url = "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=test-key"
        mock.responses[url] = (responseBody, 200)

        let provider = GeminiProvider(apiKey: "test-key", model: model, http: mock)
        let result = try await provider.complete(prompt: "Say hello")

        XCTAssertEqual(result, "你好")
        let req = mock.requestsMade[0]
        XCTAssertTrue(req.url?.absoluteString.contains("key=test-key") == true)
    }

    // MARK: - OpenAIProvider

    func test_openAI_usesOpenAIBaseURL() async throws {
        let mock = MockHTTPClient()
        let responseBody = """
        {"choices":[{"message":{"content":"Hello"}}]}
        """.data(using: .utf8)!
        mock.responses["https://api.openai.com/v1/chat/completions"] = (responseBody, 200)

        let provider = OpenAIProvider(apiKey: "sk-test", model: "gpt-4o", http: mock)
        let result = try await provider.complete(prompt: "Hi")

        XCTAssertEqual(result, "Hello")
        XCTAssertEqual(mock.requestsMade[0].url?.host, "api.openai.com")
    }

    // MARK: - OpenRouterProvider

    func test_openRouter_usesOpenRouterBaseURL() async throws {
        let mock = MockHTTPClient()
        let responseBody = """
        {"choices":[{"message":{"content":"Hallo"}}]}
        """.data(using: .utf8)!
        mock.responses["https://openrouter.ai/v1/chat/completions"] = (responseBody, 200)

        let provider = OpenRouterProvider(
            apiKey: "sk-or-test",
            model: "anthropic/claude-sonnet-4-6",
            http: mock
        )
        let result = try await provider.complete(prompt: "Say hello in German")
        XCTAssertEqual(result, "Hallo")
        XCTAssertEqual(mock.requestsMade[0].url?.host, "openrouter.ai")
    }

    func test_openRouter_fetchModels_returnsModelList() async throws {
        let mock = MockHTTPClient()
        let responseBody = """
        {"data":[
          {"id":"anthropic/claude-sonnet-4-6","name":"Claude Sonnet"},
          {"id":"openai/gpt-4o","name":"GPT-4o"}
        ]}
        """.data(using: .utf8)!
        mock.responses["https://openrouter.ai/api/v1/models"] = (responseBody, 200)

        let models = try await OpenRouterProvider.fetchModels(apiKey: "sk-or-test", http: mock)
        XCTAssertEqual(models.count, 2)
        XCTAssertEqual(models[0].id, "anthropic/claude-sonnet-4-6")
        XCTAssertEqual(models[1].name, "GPT-4o")
    }
}

// Helper for async throws assertions
func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath, line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown", file: file, line: line)
    } catch {}
}
