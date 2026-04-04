# RTM Learner — Plan 2: LLM Providers & Pipeline

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement all four LLM providers (Claude, Gemini, OpenAI, OpenRouter) and the four pipeline steps (Fetcher, Parser, Translator, PlecoExporter), fully tested with a mock provider and a mock URLSession.

**Architecture:** `LLMProvider` is a protocol injected into the pipeline steps. `URLSession` is abstracted behind `HTTPClient` (a protocol) so network calls can be stubbed in tests without hitting real APIs. `PipelineRunner` owns the four steps and executes them sequentially via async/await.

**Tech Stack:** Swift 5.9+, macOS 13.0+, URLSession, FeedKit, SwiftSoup, XCTest

**Prerequisites:** Plan 1 complete (Episode, Word, JSONRepair, Settings, StateManager all exist).

**Spec:** `docs/superpowers/specs/2026-04-04-rtm-learner-macos-app-design.md`

---

## File Map

| File | Responsibility |
|------|---------------|
| `RTMLearner/Providers/LLMProvider.swift` | `LLMProvider` protocol |
| `RTMLearner/Providers/ChatCompletionProvider.swift` | Shared OpenAI-format REST logic used by OpenAI and OpenRouter |
| `RTMLearner/Providers/ClaudeProvider.swift` | Anthropic Messages API |
| `RTMLearner/Providers/GeminiProvider.swift` | Google Generative Language API |
| `RTMLearner/Providers/OpenAIProvider.swift` | Wraps `ChatCompletionProvider` for api.openai.com |
| `RTMLearner/Providers/OpenRouterProvider.swift` | Wraps `ChatCompletionProvider` for openrouter.ai; also fetches model list |
| `RTMLearner/Support/HTTPClient.swift` | `HTTPClient` protocol + `URLSession` conformance — enables test injection |
| `RTMLearner/Pipeline/Fetcher.swift` | RSS → filter → download → HTML strip |
| `RTMLearner/Pipeline/Parser.swift` | plain text + LLM → `Episode` |
| `RTMLearner/Pipeline/Translator.swift` | `Episode` + LLM → adds `german`/`example_de` |
| `RTMLearner/Pipeline/PlecoExporter.swift` | `Episode` → `.txt` flashcard file + iCloud copy |
| `RTMLearner/Pipeline/PipelineRunner.swift` | Orchestrates steps 1–4, publishes log output |
| `RTMLearnerTests/MockLLMProvider.swift` | Configurable stub implementing `LLMProvider` |
| `RTMLearnerTests/MockHTTPClient.swift` | Configurable stub implementing `HTTPClient` |
| `RTMLearnerTests/ProviderTests.swift` | Request format tests for each provider |
| `RTMLearnerTests/FetcherTests.swift` | HTML stripping, URL filtering |
| `RTMLearnerTests/ParserTests.swift` | Prompt construction, JSON decode, JSON repair path |
| `RTMLearnerTests/TranslatorTests.swift` | german/example_de attachment, empty input guard |
| `RTMLearnerTests/PlecoExporterTests.swift` | File format, content, iCloud copy failure tolerance |
| `RTMLearnerTests/PipelineRunnerTests.swift` | Full pipeline with mock provider, missed step failure |

---

## Task 1: HTTPClient Protocol + Mocks

**Files:**
- Create: `RTMLearner/RTMLearner/Support/HTTPClient.swift`
- Create: `RTMLearner/RTMLearnerTests/MockHTTPClient.swift`
- Create: `RTMLearner/RTMLearnerTests/MockLLMProvider.swift`

- [ ] **Step 1: Create HTTPClient protocol**

  Create `RTMLearner/Support/HTTPClient.swift`:

  ```swift
  import Foundation

  protocol HTTPClient {
      func data(for request: URLRequest) async throws -> (Data, URLResponse)
  }

  extension URLSession: HTTPClient {}
  ```

- [ ] **Step 2: Create MockHTTPClient**

  Create `RTMLearnerTests/MockHTTPClient.swift`:

  ```swift
  import Foundation
  @testable import RTMLearner

  final class MockHTTPClient: HTTPClient {
      /// Map from URL string to (Data, HTTPStatus). First match wins.
      var responses: [String: (Data, Int)] = [:]
      var requestsMade: [URLRequest] = []
      var defaultResponse: (Data, Int) = (Data(), 200)

      func data(for request: URLRequest) async throws -> (Data, URLResponse) {
          requestsMade.append(request)
          let key = request.url?.absoluteString ?? ""
          let (data, status) = responses[key] ?? defaultResponse
          let response = HTTPURLResponse(
              url: request.url!, statusCode: status,
              httpVersion: nil, headerFields: nil
          )!
          return (data, response)
      }
  }
  ```

- [ ] **Step 3: Create MockLLMProvider**

  Create `RTMLearnerTests/MockLLMProvider.swift`:

  ```swift
  import Foundation
  @testable import RTMLearner

  final class MockLLMProvider: LLMProvider {
      var response: String = ""
      var error: Error?
      var callCount = 0
      var lastPrompt: String = ""

      func complete(prompt: String) async throws -> String {
          callCount += 1
          lastPrompt = prompt
          if let error { throw error }
          return response
      }
  }
  ```

- [ ] **Step 4: Build — expect success**

  `Cmd+B`. Expected: Build Succeeded (LLMProvider doesn't exist yet — add a placeholder):

  Create `RTMLearner/Providers/LLMProvider.swift`:

  ```swift
  import Foundation

  protocol LLMProvider {
      func complete(prompt: String) async throws -> String
  }
  ```

  `Cmd+B` again. Expected: Build Succeeded.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add LLMProvider protocol, HTTPClient protocol, and test mocks"
  ```

---

## Task 2: ChatCompletionProvider

**Files:**
- Create: `RTMLearner/RTMLearner/Providers/ChatCompletionProvider.swift`
- Create: `RTMLearner/RTMLearnerTests/ProviderTests.swift`

- [ ] **Step 1: Write the failing tests**

  Create `RTMLearnerTests/ProviderTests.swift`:

  ```swift
  import XCTest
  @testable import RTMLearner

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
  ```

- [ ] **Step 2: Run the tests — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'ChatCompletionProvider'".

- [ ] **Step 3: Implement ChatCompletionProvider**

  Create `RTMLearner/Providers/ChatCompletionProvider.swift`:

  ```swift
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
  ```

- [ ] **Step 4: Run the tests — expect PASS**

  `Cmd+U`. Expected: ChatCompletion tests PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add ChatCompletionProvider — shared OpenAI-format REST logic"
  ```

---

## Task 3: ClaudeProvider

**Files:**
- Create: `RTMLearner/RTMLearner/Providers/ClaudeProvider.swift`
- Modify: `RTMLearner/RTMLearnerTests/ProviderTests.swift`

- [ ] **Step 1: Write the failing test**

  Append to `ProviderTests.swift`:

  ```swift
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
  ```

- [ ] **Step 2: Run the test — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'ClaudeProvider'".

- [ ] **Step 3: Implement ClaudeProvider**

  Create `RTMLearner/Providers/ClaudeProvider.swift`:

  ```swift
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
  ```

- [ ] **Step 4: Run the test — expect PASS**

  `Cmd+U`. Expected: Claude test PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add ClaudeProvider — Anthropic Messages API"
  ```

---

## Task 4: GeminiProvider

**Files:**
- Create: `RTMLearner/RTMLearner/Providers/GeminiProvider.swift`
- Modify: `RTMLearner/RTMLearnerTests/ProviderTests.swift`

- [ ] **Step 1: Write the failing test**

  Append to `ProviderTests.swift`:

  ```swift
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
  ```

- [ ] **Step 2: Run the test — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'GeminiProvider'".

- [ ] **Step 3: Implement GeminiProvider**

  Create `RTMLearner/Providers/GeminiProvider.swift`:

  ```swift
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
  ```

- [ ] **Step 4: Run the test — expect PASS**

  `Cmd+U`. Expected: Gemini test PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add GeminiProvider — Google Generative Language API"
  ```

---

## Task 5: OpenAIProvider and OpenRouterProvider

**Files:**
- Create: `RTMLearner/RTMLearner/Providers/OpenAIProvider.swift`
- Create: `RTMLearner/RTMLearner/Providers/OpenRouterProvider.swift`
- Modify: `RTMLearner/RTMLearnerTests/ProviderTests.swift`

- [ ] **Step 1: Write the failing tests**

  Append to `ProviderTests.swift`:

  ```swift
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
  ```

- [ ] **Step 2: Run the tests — expect FAIL**

  `Cmd+U`. Expected: compiler errors for missing types.

- [ ] **Step 3: Implement OpenAIProvider**

  Create `RTMLearner/Providers/OpenAIProvider.swift`:

  ```swift
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
  ```

- [ ] **Step 4: Implement OpenRouterProvider**

  Create `RTMLearner/Providers/OpenRouterProvider.swift`:

  ```swift
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
  ```

- [ ] **Step 5: Run the tests — expect PASS**

  `Cmd+U`. Expected: all provider tests PASS.

- [ ] **Step 6: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add OpenAIProvider and OpenRouterProvider (with model list fetch)"
  ```

---

## Task 6: ProviderFactory

**Files:**
- Create: `RTMLearner/RTMLearner/Providers/ProviderFactory.swift`

- [ ] **Step 1: Implement ProviderFactory**

  This is a pure factory with no testable logic beyond what the providers already cover.

  Create `RTMLearner/Providers/ProviderFactory.swift`:

  ```swift
  import Foundation

  enum ProviderFactory {
      /// Build the active LLMProvider from current settings + Keychain.
      /// Throws KeychainError.notFound if the required API key is missing.
      static func make(settings: Settings) throws -> LLMProvider {
          switch settings.providerType {
          case .claude:
              let key = try KeychainHelper.load(for: "claude_api_key")
              return ClaudeProvider(apiKey: key, model: settings.activeModel())
          case .gemini:
              let key = try KeychainHelper.load(for: "gemini_api_key")
              return GeminiProvider(apiKey: key, model: settings.activeModel())
          case .openai:
              let key = try KeychainHelper.load(for: "openai_api_key")
              return OpenAIProvider(apiKey: key, model: settings.activeModel())
          case .openrouter:
              let key = try KeychainHelper.load(for: "openrouter_api_key")
              return OpenRouterProvider(apiKey: key, model: settings.activeModel())
          }
      }
  }
  ```

- [ ] **Step 2: Build — expect success**

  `Cmd+B`. Expected: Build Succeeded.

- [ ] **Step 3: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add ProviderFactory — builds LLMProvider from Settings + Keychain"
  ```

---

## Task 7: Fetcher

**Files:**
- Create: `RTMLearner/RTMLearner/Pipeline/Fetcher.swift`
- Create: `RTMLearner/RTMLearnerTests/FetcherTests.swift`

- [ ] **Step 1: Write the failing tests**

  Create `RTMLearnerTests/FetcherTests.swift`:

  ```swift
  import XCTest
  @testable import RTMLearner

  final class FetcherTests: XCTestCase {

      func test_extractText_prefersAvailableContentDiv() throws {
          let html = """
          <html><body>
            <nav>Navigation</nav>
            <div class="available-content"><p>Lesson text</p></div>
            <script>drop me</script>
          </body></html>
          """
          let text = try Fetcher.extractText(from: html)
          XCTAssertTrue(text.contains("Lesson text"))
          XCTAssertFalse(text.contains("Navigation"))
          XCTAssertFalse(text.contains("drop me"))
      }

      func test_extractText_fallsBackToArticle() throws {
          let html = "<html><body><article><p>Article content</p></article></body></html>"
          let text = try Fetcher.extractText(from: html)
          XCTAssertTrue(text.contains("Article content"))
      }

      func test_extractText_fallsBackToMain() throws {
          let html = "<html><body><main><p>Main content</p></main></body></html>"
          let text = try Fetcher.extractText(from: html)
          XCTAssertTrue(text.contains("Main content"))
      }

      func test_extractText_stripsScriptStyleNavFooterHeader() throws {
          let html = """
          <html><body>
            <header>Header</header>
            <main><p>Keep</p></main>
            <footer>Footer</footer>
          </body></html>
          """
          let text = try Fetcher.extractText(from: html)
          XCTAssertTrue(text.contains("Keep"))
          XCTAssertFalse(text.contains("Header"))
          XCTAssertFalse(text.contains("Footer"))
      }

      func test_filterEntries_keepsOnlyZhongjiFeedItems() {
          let items: [(title: String, url: String)] = [
              ("#265[中级]: Topic A", "https://rtm.com/265"),
              ("#100[初级]: Topic B", "https://rtm.com/100"),
              ("#300[高级]: Topic C", "https://rtm.com/300"),
          ]
          let filtered = Fetcher.filterEntries(items)
          XCTAssertEqual(filtered.count, 1)
          XCTAssertEqual(filtered[0].url, "https://rtm.com/265")
      }

      func test_parseEpisodeNumber_extractsFromTitle() {
          XCTAssertEqual(Fetcher.episodeNumber(from: "#265[中级]: Title"), 265)
          XCTAssertEqual(Fetcher.episodeNumber(from: "No number here"), 0)
      }
  }
  ```

- [ ] **Step 2: Run the tests — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'Fetcher'".

- [ ] **Step 3: Implement Fetcher**

  Create `RTMLearner/Pipeline/Fetcher.swift`:

  ```swift
  import Foundation
  import FeedKit
  import SwiftSoup

  enum FetcherError: Error {
      case httpError(statusCode: Int)
      case authenticationFailed
      case htmlParseError(String)
  }

  struct FeedEntry {
      let episode: Int
      let title: String
      let url: String
      let pubDate: String
  }

  struct Fetcher {

      // MARK: - Public API

      /// Parse the RTM RSS feed and return new (unprocessed) entries sorted oldest-first.
      static func fetchNewEntries(
          feedURL: URL = URL(string: "https://www.realtimemandarin.com/feed")!,
          stateManager: StateManager
      ) async throws -> [FeedEntry] {
          let parser = FeedParser(URL: feedURL)
          return try await withCheckedThrowingContinuation { continuation in
              parser.parseAsync { result in
                  switch result {
                  case .success(let feed):
                      guard case .rss(let rss) = feed, let items = rss.items else {
                          continuation.resume(returning: [])
                          return
                      }
                      let raw = items.compactMap { item -> (title: String, url: String)? in
                          guard let title = item.title, let url = item.link else { return nil }
                          return (title, url)
                      }
                      let filtered = filterEntries(raw)
                      Task {
                          var entries: [FeedEntry] = []
                          for (title, url) in filtered {
                              let processed = await stateManager.isProcessed(url: url)
                              if !processed {
                                  entries.append(FeedEntry(
                                      episode: episodeNumber(from: title),
                                      title: title,
                                      url: url,
                                      pubDate: ""
                                  ))
                              }
                          }
                          entries.sort { $0.episode < $1.episode }
                          continuation.resume(returning: entries)
                      }
                  case .failure(let error):
                      continuation.resume(throwing: error)
                  }
              }
          }
      }

      /// Download a Substack page using the cached session cookie.
      static func downloadPage(
          url: URL,
          sessionCookie: String,
          http: HTTPClient = URLSession.shared
      ) async throws -> String {
          var request = URLRequest(url: url)
          request.setValue("substack.sid=\(sessionCookie)", forHTTPHeaderField: "Cookie")
          request.setValue(
              "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36",
              forHTTPHeaderField: "User-Agent"
          )

          let (data, response) = try await http.data(for: request)
          guard let httpResponse = response as? HTTPURLResponse else {
              throw FetcherError.httpError(statusCode: 0)
          }
          if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
              throw FetcherError.authenticationFailed
          }
          guard (200..<300).contains(httpResponse.statusCode) else {
              throw FetcherError.httpError(statusCode: httpResponse.statusCode)
          }
          return String(data: data, encoding: .utf8) ?? ""
      }

      // MARK: - Helpers (internal for testing)

      static func filterEntries(_ items: [(title: String, url: String)]) -> [(title: String, url: String)] {
          items.filter { $0.title.contains("中级") }
      }

      static func episodeNumber(from title: String) -> Int {
          guard let match = title.range(of: #"#(\d+)"#, options: .regularExpression) else { return 0 }
          let digits = title[match].dropFirst()
          return Int(digits) ?? 0
      }

      static func extractText(from html: String) throws -> String {
          do {
              let doc = try SwiftSoup.parse(html)
              for selector in ["script", "style", "nav", "footer", "header", ".subscribe-widget"] {
                  try doc.select(selector).remove()
              }
              let content: Element = try
                  doc.select("div.available-content").first() ??
                  doc.select("div.post-content").first() ??
                  doc.select("article").first() ??
                  doc.select("main").first() ??
                  doc.body() ??
                  { throw FetcherError.htmlParseError("No body element found") }()

              return try content.text()
          } catch let error as FetcherError {
              throw error
          } catch {
              throw FetcherError.htmlParseError(error.localizedDescription)
          }
      }
  }
  ```

- [ ] **Step 4: Run the tests — expect PASS**

  `Cmd+U`. Expected: all Fetcher tests PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add Fetcher — RSS parsing, HTML extraction, URL filtering"
  ```

---

## Task 8: Parser

**Files:**
- Create: `RTMLearner/RTMLearner/Pipeline/Parser.swift`
- Create: `RTMLearner/RTMLearnerTests/ParserTests.swift`

- [ ] **Step 1: Write the failing tests**

  Create `RTMLearnerTests/ParserTests.swift`:

  ```swift
  import XCTest
  @testable import RTMLearner

  final class ParserTests: XCTestCase {

      let sampleEpisodeJSON = """
      {
        "text_simplified": "文章内容",
        "text_traditional": "文章內容",
        "words": [{"type":"priority","number":1,"chinese":"测试","pinyin":"cè shì",
                   "english":"test","example_zh":"例子","example_en":"example",
                   "german":"","example_de":""}],
        "idioms": [],
        "dialogue": [],
        "grammar": [],
        "exercises": []
      }
      """

      func test_parse_callsProviderWithLessonText() async throws {
          let mock = MockLLMProvider()
          mock.response = sampleEpisodeJSON

          let meta = FeedEntry(episode: 265, title: "Test", url: "https://x.com", pubDate: "2024-01-01")
          _ = try await Parser.parse(text: "lesson content here", entry: meta, provider: mock)

          XCTAssertTrue(mock.lastPrompt.contains("lesson content here"))
          XCTAssertEqual(mock.callCount, 1)
      }

      func test_parse_mergesMetaIntoEpisode() async throws {
          let mock = MockLLMProvider()
          mock.response = sampleEpisodeJSON

          let meta = FeedEntry(episode: 265, title: "#265[中级]: Topic", url: "https://x.com", pubDate: "2024-01-01")
          let episode = try await Parser.parse(text: "text", entry: meta, provider: mock)

          XCTAssertEqual(episode.episode, 265)
          XCTAssertEqual(episode.title, "#265[中级]: Topic")
          XCTAssertEqual(episode.url, "https://x.com")
      }

      func test_parse_decodesWordsFromResponse() async throws {
          let mock = MockLLMProvider()
          mock.response = sampleEpisodeJSON

          let episode = try await Parser.parse(
              text: "text",
              entry: FeedEntry(episode: 1, title: "T", url: "u", pubDate: "d"),
              provider: mock
          )
          XCTAssertEqual(episode.words.count, 1)
          XCTAssertEqual(episode.words[0].chinese, "测试")
      }

      func test_parse_stripsFenceFromResponse() async throws {
          let mock = MockLLMProvider()
          mock.response = "```json\n\(sampleEpisodeJSON)\n```"

          let episode = try await Parser.parse(
              text: "text",
              entry: FeedEntry(episode: 1, title: "T", url: "u", pubDate: "d"),
              provider: mock
          )
          XCTAssertEqual(episode.textSimplified, "文章内容")
      }
  }
  ```

- [ ] **Step 2: Run the tests — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'Parser'".

- [ ] **Step 3: Implement Parser**

  Create `RTMLearner/Pipeline/Parser.swift`:

  ```swift
  import Foundation

  enum ParserError: Error {
      case decodingFailed(String)
  }

  struct Parser {
      private static let prompt = """
      You are a structured data extractor for RTM Mandarin Chinese lessons.
      Extract ALL content from the lesson text below into the exact JSON structure shown.
      Return ONLY valid JSON — no markdown fences, no commentary.

      JSON schema:
      {
        "text_simplified": "the main simplified Chinese article text",
        "text_traditional": "the traditional Chinese version of the same text",
        "words": [{"type":"priority","number":1,"chinese":"内测","pinyin":"nèi cè",
          "english":"internal testing","example_zh":"","example_en":"","german":"","example_de":""}],
        "idioms": [{"type":"idiom","number":1,"chinese":"无懈可击","pinyin":"wú xiè kě jī",
          "english":"flawless","example_zh":"","example_en":"","german":"","example_de":""}],
        "dialogue": [{"speaker":"老李","line":"Chinese line"}],
        "grammar": [{"pattern":"立马 + verb","pinyin":"lì mǎ","meaning_en":"immediately",
          "examples_zh":["example 1","example 2"]}],
        "exercises": [{"question":"question with ___","options":["a","b","c","d"],
          "answer_index":1,"answer_text":"correct"}]
      }

      Lesson text:
      """

      static func parse(
          text: String,
          entry: FeedEntry,
          provider: LLMProvider
      ) async throws -> Episode {
          let raw = try await provider.complete(prompt: prompt + text)
          guard let data = JSONRepair.repair(raw) else {
              throw ParserError.decodingFailed("JSON repair failed")
          }
          var episode = try JSONDecoder().decode(Episode.self, from: data)
          // Merge feed metadata
          episode.episode = entry.episode
          episode.title   = entry.title
          episode.url     = entry.url
          episode.pubDate = entry.pubDate
          return episode
      }
  }
  ```

- [ ] **Step 4: Run the tests — expect PASS**

  `Cmd+U`. Expected: all Parser tests PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add Parser — LLM extraction prompt and Episode decoding"
  ```

---

## Task 9: Translator

**Files:**
- Create: `RTMLearner/RTMLearner/Pipeline/Translator.swift`
- Create: `RTMLearner/RTMLearnerTests/TranslatorTests.swift`

- [ ] **Step 1: Write the failing tests**

  Create `RTMLearnerTests/TranslatorTests.swift`:

  ```swift
  import XCTest
  @testable import RTMLearner

  final class TranslatorTests: XCTestCase {

      func test_translate_returnsUnchangedWhenNoWordsOrIdioms() async throws {
          let mock = MockLLMProvider()
          var episode = makeEpisode(words: [], idioms: [])
          try await Translator.translate(episode: &episode, provider: mock)
          XCTAssertEqual(mock.callCount, 0)
      }

      func test_translate_addsGermanAndExampleDe() async throws {
          let mock = MockLLMProvider()
          mock.response = """
          [{"german":"Test","example_de":"Das ist ein Test"}]
          """
          var episode = makeEpisode(
              words: [Word(type:"priority",number:1,chinese:"测试",pinyin:"cè shì",
                          english:"test",exampleZh:"例子",exampleEn:"example")],
              idioms: []
          )
          try await Translator.translate(episode: &episode, provider: mock)
          XCTAssertEqual(episode.words[0].german, "Test")
          XCTAssertEqual(episode.words[0].exampleDe, "Das ist ein Test")
      }

      func test_translate_includesTopicInPrompt() async throws {
          let mock = MockLLMProvider()
          mock.response = "[{\"german\":\"x\",\"example_de\":\"x\"}]"
          var episode = makeEpisode(
              words: [Word(type:"priority",number:1,chinese:"测试",pinyin:"cè shì",
                          english:"test",exampleZh:"",exampleEn:"")],
              idioms: []
          )
          episode.title = "AI and Technology"
          try await Translator.translate(episode: &episode, provider: mock)
          XCTAssertTrue(mock.lastPrompt.contains("AI and Technology"))
      }

      func test_translate_separatesWordsAndIdioms() async throws {
          let mock = MockLLMProvider()
          mock.response = """
          [{"german":"Test","example_de":""},{"german":"einwandfrei","example_de":""}]
          """
          var episode = makeEpisode(
              words: [Word(type:"priority",number:1,chinese:"测试",pinyin:"",english:"test",exampleZh:"",exampleEn:"")],
              idioms: [Word(type:"idiom",number:1,chinese:"无懈可击",pinyin:"",english:"flawless",exampleZh:"",exampleEn:"")]
          )
          try await Translator.translate(episode: &episode, provider: mock)
          XCTAssertEqual(episode.words[0].german, "Test")
          XCTAssertEqual(episode.idioms[0].german, "einwandfrei")
      }

      // MARK: - Helper

      private func makeEpisode(words: [Word], idioms: [Word]) -> Episode {
          Episode(episode: 1, title: "Test", url: "https://x.com", pubDate: "2024-01-01",
                  textSimplified: "", textTraditional: "",
                  words: words, idioms: idioms, dialogue: [], grammar: [], exercises: [])
      }
  }
  ```

- [ ] **Step 2: Run the tests — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'Translator'".

- [ ] **Step 3: Implement Translator**

  Create `RTMLearner/Pipeline/Translator.swift`:

  ```swift
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
          let results = try JSONDecoder().decode([TranslationResult].self, from: data)

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
  ```

- [ ] **Step 4: Run the tests — expect PASS**

  `Cmd+U`. Expected: all Translator tests PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add Translator — German translation via LLM"
  ```

---

## Task 10: PlecoExporter

**Files:**
- Create: `RTMLearner/RTMLearner/Pipeline/PlecoExporter.swift`
- Create: `RTMLearner/RTMLearnerTests/PlecoExporterTests.swift`

- [ ] **Step 1: Write the failing tests**

  Create `RTMLearnerTests/PlecoExporterTests.swift`:

  ```swift
  import XCTest
  @testable import RTMLearner

  final class PlecoExporterTests: XCTestCase {

      var tempDir: URL!

      override func setUp() {
          super.setUp()
          tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
          try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
      }

      override func tearDown() {
          try? FileManager.default.removeItem(at: tempDir)
          super.tearDown()
      }

      func test_export_createsFile() throws {
          let episode = makeEpisode()
          try PlecoExporter.export(episode: episode, to: tempDir, iCloudDir: nil)
          let file = tempDir.appendingPathComponent("265_pleco.txt")
          XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
      }

      func test_export_writesHeaderComment() throws {
          let episode = makeEpisode()
          try PlecoExporter.export(episode: episode, to: tempDir, iCloudDir: nil)
          let content = try String(contentsOf: tempDir.appendingPathComponent("265_pleco.txt"))
          XCTAssertTrue(content.hasPrefix("// RTM #265:"))
      }

      func test_export_writesTabSeparatedCardLine() throws {
          let episode = makeEpisode()
          try PlecoExporter.export(episode: episode, to: tempDir, iCloudDir: nil)
          let content = try String(contentsOf: tempDir.appendingPathComponent("265_pleco.txt"))
          XCTAssertTrue(content.contains("测试\tcè shì\tTest | 例子 Das ist ein Test"))
      }

      func test_export_fallsBackToEnglishWhenGermanEmpty() throws {
          var episode = makeEpisode()
          episode.words[0].german = ""
          try PlecoExporter.export(episode: episode, to: tempDir, iCloudDir: nil)
          let content = try String(contentsOf: tempDir.appendingPathComponent("265_pleco.txt"))
          XCTAssertTrue(content.contains("测试\tcè shì\ttest"))
      }

      func test_export_iCloudFailureDoesNotThrow() {
          let episode = makeEpisode()
          let nonExistentICloud = URL(fileURLWithPath: "/nonexistent/path/that/does/not/exist")
          XCTAssertNoThrow(try PlecoExporter.export(episode: episode, to: tempDir, iCloudDir: nonExistentICloud))
      }

      // MARK: - Helper

      private func makeEpisode() -> Episode {
          var episode = Episode(
              episode: 265, title: "#265[中级]: AI and Technology",
              url: "https://x.com", pubDate: "2024-01-01",
              textSimplified: "", textTraditional: "",
              words: [
                  Word(type:"priority", number:1, chinese:"测试", pinyin:"cè shì",
                       english:"test", exampleZh:"例子", exampleEn:"example",
                       german:"Test", exampleDe:"Das ist ein Test")
              ],
              idioms: [], dialogue: [], grammar: [], exercises: []
          )
          return episode
      }
  }
  ```

- [ ] **Step 2: Run the tests — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'PlecoExporter'".

- [ ] **Step 3: Implement PlecoExporter**

  Create `RTMLearner/Pipeline/PlecoExporter.swift`:

  ```swift
  import Foundation

  struct PlecoExporter {

      /// Write a Pleco-compatible flashcard .txt file and optionally copy to iCloud.
      /// iCloud copy failure is logged but never throws.
      @discardableResult
      static func export(
          episode: Episode,
          to outputDir: URL,
          iCloudDir: URL?
      ) throws -> URL {
          let lines = buildLines(episode: episode)
          let content = lines.joined(separator: "\n")

          try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
          let fileURL = outputDir.appendingPathComponent("\(episode.episode)_pleco.txt")
          try content.write(to: fileURL, atomically: true, encoding: .utf8)

          if let iCloud = iCloudDir {
              do {
                  try FileManager.default.createDirectory(at: iCloud, withIntermediateDirectories: true)
                  let dest = iCloud.appendingPathComponent(fileURL.lastPathComponent)
                  if FileManager.default.fileExists(atPath: dest.path) {
                      try FileManager.default.removeItem(at: dest)
                  }
                  try FileManager.default.copyItem(at: fileURL, to: dest)
              } catch {
                  print("iCloud copy failed (non-fatal): \(error)")
              }
          }
          return fileURL
      }

      // MARK: - Helpers

      private static func buildLines(episode: Episode) -> [String] {
          var lines: [String] = []
          let shortTitle = episode.title
              .replacingOccurrences(of: #"^#\d+\[.*?\]:\s*"#, with: "", options: .regularExpression)
          lines.append("// RTM #\(episode.episode): \(shortTitle)")
          lines.append("")

          for word in episode.words + episode.idioms {
              lines.append(cardLine(word))
          }
          lines.append("")
          return lines
      }

      private static func cardLine(_ word: Word) -> String {
          let definition = word.german.isEmpty ? word.english : word.german
          let cleaned = clean(definition)
          let exZh = clean(word.exampleZh)
          let exDe = clean(word.exampleDe)

          var def = cleaned
          if !exZh.isEmpty {
              def += " | \(exZh)"
              if !exDe.isEmpty { def += " \(exDe)" }
          }
          return "\(word.chinese)\t\(word.pinyin)\t\(def)"
      }

      private static func clean(_ s: String) -> String {
          s.replacingOccurrences(of: "\\\"", with: "\"")
           .replacingOccurrences(of: "\u{201E}", with: "\"")
           .replacingOccurrences(of: "\u{201C}", with: "\"")
           .replacingOccurrences(of: "\u{201D}", with: "\"")
           .replacingOccurrences(of: "\u{2018}", with: "'")
           .replacingOccurrences(of: "\u{2019}", with: "'")
      }
  }
  ```

- [ ] **Step 4: Run the tests — expect PASS**

  `Cmd+U`. Expected: all PlecoExporter tests PASS.

- [ ] **Step 5: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add PlecoExporter — Pleco flashcard file writer"
  ```

---

## Task 11: PipelineRunner

**Files:**
- Create: `RTMLearner/RTMLearner/Pipeline/PipelineRunner.swift`
- Create: `RTMLearner/RTMLearnerTests/PipelineRunnerTests.swift`

- [ ] **Step 1: Write the failing tests**

  Create `RTMLearnerTests/PipelineRunnerTests.swift`:

  ```swift
  import XCTest
  @testable import RTMLearner

  final class PipelineRunnerTests: XCTestCase {

      let sampleJSON = """
      {"text_simplified":"文章","text_traditional":"文章",
       "words":[{"type":"priority","number":1,"chinese":"测试","pinyin":"cè shì",
                 "english":"test","example_zh":"","example_en":"","german":"","example_de":""}],
       "idioms":[],"dialogue":[],"grammar":[],"exercises":[]}
      """

      func test_run_completesSuccessfully() async throws {
          let mock = MockLLMProvider()
          mock.response = sampleJSON // used for both parse and translate calls

          let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
          defer { try? FileManager.default.removeItem(at: tempDir) }

          let stateDir = tempDir.appendingPathComponent("state")
          let outputDir = tempDir.appendingPathComponent("output")
          let stateManager = await StateManager(directory: stateDir)

          var logOutput = ""
          let entry = FeedEntry(episode: 1, title: "#1[中级]: Test", url: "https://x.com", pubDate: "2024-01-01")

          try await PipelineRunner.run(
              entry: entry,
              html: "<main><p>Lesson text</p></main>",
              provider: mock,
              stateManager: stateManager,
              outputDir: outputDir,
              iCloudDir: nil,
              log: { logOutput += $0 + "\n" }
          )

          // Provider was called twice (parse + translate)
          XCTAssertEqual(mock.callCount, 2)
          // Pleco file was created
          let plecoFile = outputDir.appendingPathComponent("pleco/1_pleco.txt")
          XCTAssertTrue(FileManager.default.fileExists(atPath: plecoFile.path))
          // Episode JSON was saved
          let episodeFile = outputDir.appendingPathComponent("episodes/1.json")
          XCTAssertTrue(FileManager.default.fileExists(atPath: episodeFile.path))
          // URL marked as processed
          let processed = await stateManager.isProcessed(url: "https://x.com")
          XCTAssertTrue(processed)
      }

      func test_run_logsEachStep() async throws {
          let mock = MockLLMProvider()
          mock.response = sampleJSON

          let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
          defer { try? FileManager.default.removeItem(at: tempDir) }

          let stateManager = await StateManager(directory: tempDir.appendingPathComponent("state"))
          let entry = FeedEntry(episode: 1, title: "#1[中级]: Test", url: "https://x.com", pubDate: "d")
          var log = ""

          try await PipelineRunner.run(
              entry: entry, html: "<main><p>text</p></main>",
              provider: mock, stateManager: stateManager,
              outputDir: tempDir.appendingPathComponent("out"),
              iCloudDir: nil,
              log: { log += $0 + "\n" }
          )

          XCTAssertTrue(log.contains("Extracting"))
          XCTAssertTrue(log.contains("Translating"))
          XCTAssertTrue(log.contains("Saving"))
      }
  }
  ```

- [ ] **Step 2: Run the tests — expect FAIL**

  `Cmd+U`. Expected: compiler error "Cannot find type 'PipelineRunner'".

- [ ] **Step 3: Implement PipelineRunner**

  Create `RTMLearner/Pipeline/PipelineRunner.swift`:

  ```swift
  import Foundation

  struct PipelineRunner {

      /// Run all four pipeline steps for a single feed entry.
      /// - Parameters:
      ///   - entry: Feed metadata (episode number, title, URL, pubDate)
      ///   - html: Raw HTML of the Substack page (already downloaded)
      ///   - provider: The active LLMProvider
      ///   - stateManager: Tracks processed URLs
      ///   - outputDir: Root output directory (episodes/ and pleco/ subdirs are created inside)
      ///   - iCloudDir: Optional iCloud Drive destination for Pleco file
      ///   - log: Callback for each log line
      static func run(
          entry: FeedEntry,
          html: String,
          provider: LLMProvider,
          stateManager: StateManager,
          outputDir: URL,
          iCloudDir: URL?,
          log: (String) -> Void
      ) async throws {
          log("[1/4] Extracting text…")
          let text = try Fetcher.extractText(from: html)

          log("[2/4] Extracting structure via LLM…")
          var episode = try await Parser.parse(text: text, entry: entry, provider: provider)

          log("[3/4] Translating to German…")
          try await Translator.translate(episode: &episode, provider: provider)

          log("[4/4] Saving outputs…")

          // Save episode JSON
          let episodesDir = outputDir.appendingPathComponent("episodes")
          try FileManager.default.createDirectory(at: episodesDir, withIntermediateDirectories: true)
          let episodeFile = episodesDir.appendingPathComponent("\(entry.episode).json")
          let episodeData = try JSONEncoder().encode(episode)
          try episodeData.write(to: episodeFile, options: .atomic)
          log("  JSON  → \(episodeFile.path)")

          // Export Pleco file
          let plecoDir = outputDir.appendingPathComponent("pleco")
          let plecoFile = try PlecoExporter.export(episode: episode, to: plecoDir, iCloudDir: iCloudDir)
          log("  Pleco → \(plecoFile.path)")

          // Mark URL as processed
          try await stateManager.markProcessed(url: entry.url)
          try await stateManager.setLastRunDate(Date())
          log("  ✓ Episode #\(entry.episode) complete")
      }
  }
  ```

- [ ] **Step 4: Run the tests — expect PASS**

  `Cmd+U`. Expected: all PipelineRunner tests PASS.

- [ ] **Step 5: Run the full test suite**

  `Cmd+U`. Expected: all tests PASS, 0 failures.

- [ ] **Step 6: Commit**

  ```bash
  git add RTMLearner/
  git commit -m "feat: add PipelineRunner — orchestrates all four pipeline steps"
  ```

---

## Plan 2 Complete

All providers and pipeline steps are implemented and tested. The pipeline can be exercised entirely with mocks — no real API keys or network calls required.

Continue with **Plan 3: App, UI & Distribution**.
