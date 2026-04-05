import Foundation

/// Runs the full fetch → parse → translate → export pipeline with injectable
/// dependencies, making the logic testable without Keychain or real network access.
///
/// `AppDelegate.runPipeline()` is responsible for resolving the session cookie
/// and LLM provider from Keychain/Settings, then handing them to this type.
struct PipelineOrchestrator {
    let sessionCookie: String
    let provider: LLMProvider
    let stateManager: StateManager
    let http: HTTPClient
    let feedURL: URL
    let outputDir: URL
    let iCloudDir: URL?

    func run(log: (String) -> Void) async {
        do {
            let entries = try await Fetcher.fetchNewEntries(feedURL: feedURL, stateManager: stateManager)
            if entries.isEmpty {
                log("No new 中级 episodes found.")
                return
            }
            for entry in entries {
                log("\n→ Episode #\(entry.episode): \(entry.title)")
                let pageURL = URL(string: entry.url)!
                let html = try await Fetcher.downloadPage(
                    url: pageURL,
                    sessionCookie: sessionCookie,
                    http: http
                )
                try await PipelineRunner.run(
                    entry: entry,
                    html: html,
                    provider: provider,
                    stateManager: stateManager,
                    outputDir: outputDir,
                    iCloudDir: iCloudDir,
                    log: log
                )
            }
        } catch {
            log("Pipeline error: \(error.localizedDescription)")
        }
    }
}
