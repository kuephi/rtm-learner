import XCTest
@testable import RTM_Learner

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
        Episode(
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
    }
}
