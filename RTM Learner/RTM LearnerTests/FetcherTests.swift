import XCTest
@testable import RTM_Learner

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
