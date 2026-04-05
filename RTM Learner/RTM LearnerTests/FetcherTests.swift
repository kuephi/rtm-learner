import XCTest
@testable import RTM_Learner

final class FetcherTests: XCTestCase {

    // MARK: - downloadPage

    func test_downloadPage_returns200_returnsHtml() async throws {
        let mock = MockHTTPClient()
        mock.responses["https://example.com/lesson"] = ("<html>Lesson</html>".data(using: .utf8)!, 200)

        let html = try await Fetcher.downloadPage(
            url: URL(string: "https://example.com/lesson")!,
            sessionCookie: "abc123",
            http: mock
        )

        XCTAssertTrue(html.contains("Lesson"))
    }

    func test_downloadPage_sendsCookieHeader() async throws {
        let mock = MockHTTPClient()
        mock.defaultResponse = ("<p>ok</p>".data(using: .utf8)!, 200)

        _ = try await Fetcher.downloadPage(
            url: URL(string: "https://example.com")!,
            sessionCookie: "sid_abc",
            http: mock
        )

        XCTAssertEqual(
            mock.requestsMade.first?.value(forHTTPHeaderField: "Cookie"),
            "substack.sid=sid_abc"
        )
    }

    func test_downloadPage_401_throwsAuthenticationFailed() async throws {
        let mock = MockHTTPClient()
        mock.defaultResponse = (Data(), 401)

        do {
            _ = try await Fetcher.downloadPage(url: URL(string: "https://example.com")!, sessionCookie: "x", http: mock)
            XCTFail("Expected authenticationFailed")
        } catch FetcherError.authenticationFailed { }
    }

    func test_downloadPage_403_throwsAuthenticationFailed() async throws {
        let mock = MockHTTPClient()
        mock.defaultResponse = (Data(), 403)

        do {
            _ = try await Fetcher.downloadPage(url: URL(string: "https://example.com")!, sessionCookie: "x", http: mock)
            XCTFail("Expected authenticationFailed")
        } catch FetcherError.authenticationFailed { }
    }

    func test_downloadPage_500_throwsHttpError() async throws {
        let mock = MockHTTPClient()
        mock.defaultResponse = (Data(), 500)

        do {
            _ = try await Fetcher.downloadPage(url: URL(string: "https://example.com")!, sessionCookie: "x", http: mock)
            XCTFail("Expected httpError")
        } catch FetcherError.httpError(let code) {
            XCTAssertEqual(code, 500)
        }
    }

    // MARK: - fetchNewEntries (local RSS file — no network)

    func test_fetchNewEntries_returnsOnlyZhongjiEntries() async throws {
        let feedURL = try makeRSSFeed(items: [
            (title: "#265[中级]: Topic A", link: "https://rtm.com/265"),
            (title: "#100[初级]: Topic B", link: "https://rtm.com/100"),
        ])
        defer { try? FileManager.default.removeItem(at: feedURL) }

        let stateManager = StateManager(directory: tempStateDir())
        let entries = try await Fetcher.fetchNewEntries(feedURL: feedURL, stateManager: stateManager)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].episode, 265)
    }

    func test_fetchNewEntries_excludesAlreadyProcessedURLs() async throws {
        let feedURL = try makeRSSFeed(items: [
            (title: "#265[中级]: A", link: "https://rtm.com/265"),
            (title: "#266[中级]: B", link: "https://rtm.com/266"),
        ])
        defer { try? FileManager.default.removeItem(at: feedURL) }

        let stateManager = StateManager(directory: tempStateDir())
        try await stateManager.markProcessed(url: "https://rtm.com/265")

        let entries = try await Fetcher.fetchNewEntries(feedURL: feedURL, stateManager: stateManager)

        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].episode, 266)
    }

    func test_fetchNewEntries_sortsByEpisodeNumberOldestFirst() async throws {
        let feedURL = try makeRSSFeed(items: [
            (title: "#300[中级]: C", link: "https://rtm.com/300"),
            (title: "#265[中级]: A", link: "https://rtm.com/265"),
            (title: "#280[中级]: B", link: "https://rtm.com/280"),
        ])
        defer { try? FileManager.default.removeItem(at: feedURL) }

        let stateManager = StateManager(directory: tempStateDir())
        let entries = try await Fetcher.fetchNewEntries(feedURL: feedURL, stateManager: stateManager)

        XCTAssertEqual(entries.map(\.episode), [265, 280, 300])
    }

    // MARK: - Fixture helpers

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

// MARK: - Shared RSS fixture builder (used by FetcherTests and PipelineOrchestratorTests)

func makeRSSFeed(items: [(title: String, link: String)]) throws -> URL {
    let itemsXML = items.map { item in
        "<item><title>\(item.title)</title><link>\(item.link)</link></item>"
    }.joined(separator: "\n    ")
    let xml = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>RTM Test Feed</title>
        \(itemsXML)
      </channel>
    </rss>
    """
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).xml")
    try xml.data(using: .utf8)!.write(to: url)
    return url
}

func tempStateDir() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
}
