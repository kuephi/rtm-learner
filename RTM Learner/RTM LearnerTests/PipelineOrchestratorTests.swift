import XCTest
@testable import RTM_Learner

final class PipelineOrchestratorTests: XCTestCase {

    // Sample LLM response accepted by Parser + Translator
    private let validLLMResponse = """
    {"text_simplified":"文章","text_traditional":"文章",
     "words":[{"type":"priority","number":1,"chinese":"测试","pinyin":"cè shì",
               "english":"test","example_zh":"","example_en":"","german":"","example_de":""}],
     "idioms":[],"dialogue":[],"grammar":[],"exercises":[]}
    """

    // MARK: - No new episodes

    func test_run_logsNoNewEpisodes_whenFeedHasNoZhongji() async throws {
        let feedURL = try makeRSSFeed(items: [
            (title: "#100[初级]: Beginner only", link: "https://rtm.com/100")
        ])
        defer { try? FileManager.default.removeItem(at: feedURL) }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let orchestrator = PipelineOrchestrator(
            sessionCookie: "test-cookie",
            provider: MockLLMProvider(),
            stateManager: StateManager(directory: tempDir.appendingPathComponent("state")),
            http: MockHTTPClient(),
            feedURL: feedURL,
            outputDir: tempDir.appendingPathComponent("output"),
            iCloudDir: nil
        )

        var log = ""
        await orchestrator.run { log += $0 + "\n" }

        XCTAssertTrue(log.contains("No new 中级 episodes found."),
                      "Expected 'no new episodes' message, got: \(log)")
    }

    func test_run_logsNoNewEpisodes_whenAllAlreadyProcessed() async throws {
        let feedURL = try makeRSSFeed(items: [
            (title: "#265[中级]: Already done", link: "https://rtm.com/265")
        ])
        defer { try? FileManager.default.removeItem(at: feedURL) }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let stateManager = StateManager(directory: tempDir.appendingPathComponent("state"))
        try await stateManager.markProcessed(url: "https://rtm.com/265")

        let orchestrator = PipelineOrchestrator(
            sessionCookie: "test-cookie",
            provider: MockLLMProvider(),
            stateManager: stateManager,
            http: MockHTTPClient(),
            feedURL: feedURL,
            outputDir: tempDir.appendingPathComponent("output"),
            iCloudDir: nil
        )

        var log = ""
        await orchestrator.run { log += $0 + "\n" }

        XCTAssertTrue(log.contains("No new 中级 episodes found."))
    }

    // MARK: - Successful processing

    func test_run_logsEpisodeTitleBeforeProcessing() async throws {
        let feedURL = try makeRSSFeed(items: [
            (title: "#265[中级]: Great Topic", link: "https://rtm.com/265")
        ])
        defer { try? FileManager.default.removeItem(at: feedURL) }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mock = MockHTTPClient()
        mock.defaultResponse = ("<main><p>Lesson text</p></main>".data(using: .utf8)!, 200)

        let provider = MockLLMProvider()
        provider.response = validLLMResponse

        let orchestrator = PipelineOrchestrator(
            sessionCookie: "test-cookie",
            provider: provider,
            stateManager: StateManager(directory: tempDir.appendingPathComponent("state")),
            http: mock,
            feedURL: feedURL,
            outputDir: tempDir.appendingPathComponent("output"),
            iCloudDir: nil
        )

        var log = ""
        await orchestrator.run { log += $0 + "\n" }

        XCTAssertTrue(log.contains("265"), "Log must contain episode number")
        XCTAssertTrue(log.contains("Great Topic"), "Log must contain episode title")
    }

    func test_run_marksEpisodeProcessedAfterSuccess() async throws {
        let feedURL = try makeRSSFeed(items: [
            (title: "#265[中级]: Test Topic", link: "https://rtm.com/265")
        ])
        defer { try? FileManager.default.removeItem(at: feedURL) }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mock = MockHTTPClient()
        mock.defaultResponse = ("<main><p>Lesson text</p></main>".data(using: .utf8)!, 200)

        let provider = MockLLMProvider()
        provider.response = validLLMResponse

        let stateManager = StateManager(directory: tempDir.appendingPathComponent("state"))

        let orchestrator = PipelineOrchestrator(
            sessionCookie: "test-cookie",
            provider: provider,
            stateManager: stateManager,
            http: mock,
            feedURL: feedURL,
            outputDir: tempDir.appendingPathComponent("output"),
            iCloudDir: nil
        )

        await orchestrator.run { _ in }

        let processed = await stateManager.isProcessed(url: "https://rtm.com/265")
        XCTAssertTrue(processed, "Episode URL must be marked processed after successful run")
    }

    func test_run_callsProviderForParseAndTranslate() async throws {
        let feedURL = try makeRSSFeed(items: [
            (title: "#265[中级]: Vocab", link: "https://rtm.com/265")
        ])
        defer { try? FileManager.default.removeItem(at: feedURL) }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mock = MockHTTPClient()
        mock.defaultResponse = ("<main><p>Some lesson</p></main>".data(using: .utf8)!, 200)

        let provider = MockLLMProvider()
        provider.response = validLLMResponse

        let orchestrator = PipelineOrchestrator(
            sessionCookie: "test-cookie",
            provider: provider,
            stateManager: StateManager(directory: tempDir.appendingPathComponent("state")),
            http: mock,
            feedURL: feedURL,
            outputDir: tempDir.appendingPathComponent("output"),
            iCloudDir: nil
        )

        await orchestrator.run { _ in }

        // PipelineRunner calls provider twice: once to parse, once to translate
        XCTAssertEqual(provider.callCount, 2,
                       "Provider should be called once for parsing and once for translation")
    }

    // MARK: - Error handling

    func test_run_logsError_whenPageDownloadFails() async throws {
        let feedURL = try makeRSSFeed(items: [
            (title: "#265[中级]: Test", link: "https://rtm.com/265")
        ])
        defer { try? FileManager.default.removeItem(at: feedURL) }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mock = MockHTTPClient()
        mock.defaultResponse = (Data(), 401)   // auth failure on page download

        let orchestrator = PipelineOrchestrator(
            sessionCookie: "bad-cookie",
            provider: MockLLMProvider(),
            stateManager: StateManager(directory: tempDir.appendingPathComponent("state")),
            http: mock,
            feedURL: feedURL,
            outputDir: tempDir.appendingPathComponent("output"),
            iCloudDir: nil
        )

        var log = ""
        await orchestrator.run { log += $0 + "\n" }

        XCTAssertTrue(log.lowercased().contains("error") || log.lowercased().contains("pipeline"),
                      "Must log error on download failure, got: \(log)")
    }

    func test_run_logsError_whenLLMFails() async throws {
        let feedURL = try makeRSSFeed(items: [
            (title: "#265[中级]: Test", link: "https://rtm.com/265")
        ])
        defer { try? FileManager.default.removeItem(at: feedURL) }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mock = MockHTTPClient()
        mock.defaultResponse = ("<main><p>text</p></main>".data(using: .utf8)!, 200)

        let provider = MockLLMProvider()
        provider.error = NSError(domain: "LLM", code: 503, userInfo: [NSLocalizedDescriptionKey: "Service unavailable"])

        let orchestrator = PipelineOrchestrator(
            sessionCookie: "test-cookie",
            provider: provider,
            stateManager: StateManager(directory: tempDir.appendingPathComponent("state")),
            http: mock,
            feedURL: feedURL,
            outputDir: tempDir.appendingPathComponent("output"),
            iCloudDir: nil
        )

        var log = ""
        await orchestrator.run { log += $0 + "\n" }

        XCTAssertTrue(log.contains("Pipeline error:"),
                      "Must log 'Pipeline error:' on LLM failure, got: \(log)")
    }

    func test_run_doesNotMarkProcessed_whenPipelineFails() async throws {
        let feedURL = try makeRSSFeed(items: [
            (title: "#265[中级]: Test", link: "https://rtm.com/265")
        ])
        defer { try? FileManager.default.removeItem(at: feedURL) }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let mock = MockHTTPClient()
        mock.defaultResponse = (Data(), 401)   // download fails → pipeline never runs

        let stateManager = StateManager(directory: tempDir.appendingPathComponent("state"))

        let orchestrator = PipelineOrchestrator(
            sessionCookie: "bad-cookie",
            provider: MockLLMProvider(),
            stateManager: stateManager,
            http: mock,
            feedURL: feedURL,
            outputDir: tempDir.appendingPathComponent("output"),
            iCloudDir: nil
        )

        await orchestrator.run { _ in }

        let processed = await stateManager.isProcessed(url: "https://rtm.com/265")
        XCTAssertFalse(processed, "Failed episode must not be marked as processed")
    }
}
