import Foundation
import Observation

@Observable
final class AppLog {
    var text: String = ""
    var isPipelineRunning: Bool = false

    private let logFileURL: URL?

    init(logFileURL: URL? = nil) {
        self.logFileURL = logFileURL
    }

    func append(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let line = "[\(timestamp)] \(message)\n"
        text += line
        if let url = logFileURL {
            appendToFile(line: line, url: url)
        }
    }

    func clear() {
        text = ""
    }

    // MARK: - Private

    private func appendToFile(line: String, url: URL) {
        guard let data = line.data(using: .utf8) else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            }
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }
}
