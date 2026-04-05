import Foundation

struct PlecoExporter {

    /// Write a Pleco-compatible flashcard .txt file and optionally copy to iCloud.
    /// iCloud copy failure is logged but never throws.
    @discardableResult
    static func export(
        episode: Episode,
        to outputDir: URL,
        iCloudDir: URL?
    ) throws -> URL {
        let lines = buildLines(episode: episode)
        let content = lines.joined(separator: "\n")

        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let fileURL = outputDir.appendingPathComponent("\(episode.episode)_pleco.txt")
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        if let iCloud = iCloudDir {
            do {
                try FileManager.default.createDirectory(at: iCloud, withIntermediateDirectories: true)
                let dest = iCloud.appendingPathComponent(fileURL.lastPathComponent)
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.copyItem(at: fileURL, to: dest)
            } catch {
                print("iCloud copy failed (non-fatal): \(error)")
            }
        }
        return fileURL
    }

    // MARK: - Helpers

    private static func buildLines(episode: Episode) -> [String] {
        var lines: [String] = []
        let shortTitle = episode.title
            .replacingOccurrences(of: #"^#\d+\[.*?\]:\s*"#, with: "", options: .regularExpression)
        lines.append("// RTM #\(episode.episode): \(shortTitle)")
        lines.append("")

        for word in episode.words + episode.idioms {
            lines.append(cardLine(word))
        }
        lines.append("")
        return lines
    }

    private static func cardLine(_ word: Word) -> String {
        let definition = word.german.isEmpty ? word.english : word.german
        let cleaned = clean(definition)
        let exZh = clean(word.exampleZh)
        let exDe = clean(word.exampleDe)

        var def = cleaned
        if !exZh.isEmpty {
            def += " | \(exZh)"
            if !exDe.isEmpty { def += " \(exDe)" }
        }
        return "\(word.chinese)\t\(word.pinyin)\t\(def)"
    }

    private static func clean(_ s: String) -> String {
        s.replacingOccurrences(of: "\\\"", with: "\"")
         .replacingOccurrences(of: "\u{201E}", with: "\"")
         .replacingOccurrences(of: "\u{201C}", with: "\"")
         .replacingOccurrences(of: "\u{201D}", with: "\"")
         .replacingOccurrences(of: "\u{2018}", with: "'")
         .replacingOccurrences(of: "\u{2019}", with: "'")
    }
}
