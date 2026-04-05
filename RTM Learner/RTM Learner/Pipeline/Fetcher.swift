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
        let feed = try await Feed(url: feedURL)
        guard case .rss(let rss) = feed,
              let items = rss.channel?.items else { return [] }

        let raw = items.compactMap { item -> (title: String, url: String)? in
            guard let title = item.title, let url = item.link else { return nil }
            return (title, url)
        }
        let filtered = filterEntries(raw)

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
        return entries
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
