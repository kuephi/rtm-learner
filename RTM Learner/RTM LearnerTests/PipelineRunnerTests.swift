import XCTest
@testable import RTM_Learner

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
        let stateManager = StateManager(directory: stateDir)

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

        let stateManager = StateManager(directory: tempDir.appendingPathComponent("state"))
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
