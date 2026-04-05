import Foundation

actor StateManager {
    static let shared: StateManager = {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("RTMLearner")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        return StateManager(directory: appSupport)
    }()

    private var state: PersistedState
    private let fileURL: URL

    private struct PersistedState: Codable {
        var processedURLs: [String] = []
        var lastRunDate: Date?

        enum CodingKeys: String, CodingKey {
            case processedURLs = "processed_urls"
            case lastRunDate   = "last_run_date"
        }
    }

    init(directory: URL) {
        fileURL = directory.appendingPathComponent("state.json")
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(PersistedState.self, from: data) {
            state = loaded
        } else {
            state = PersistedState()
        }
    }

    func isProcessed(url: String) -> Bool {
        state.processedURLs.contains(url)
    }

    func markProcessed(url: String) throws {
        state.processedURLs.append(url)
        try persist()
    }

    var lastRunDate: Date? { state.lastRunDate }

    func setLastRunDate(_ date: Date) throws {
        state.lastRunDate = date
        try persist()
    }

    private func persist() throws {
        let data = try JSONEncoder().encode(state)
        try data.write(to: fileURL, options: .atomic)
    }
}

extension StateManager {
    /// Call once at app launch. Copies data/state.json from the old Python project
    /// into Application Support if it exists and the new state file doesn't yet.
    static func migrateFromPythonProjectIfNeeded(pythonDataDir: URL) async {
        let source = pythonDataDir.appendingPathComponent("state.json")
        guard FileManager.default.fileExists(atPath: source.path) else { return }
        let dest = await shared.fileURL
        guard !FileManager.default.fileExists(atPath: dest.path) else { return }
        try? FileManager.default.copyItem(at: source, to: dest)
    }
}
