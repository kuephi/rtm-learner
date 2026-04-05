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
