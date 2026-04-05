import Foundation

enum JSONRepair {

    /// Strip markdown code fences and trim whitespace.
    static func clean(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            s = s.replacingOccurrences(
                of: #"^```(?:json)?\s*"#, with: "",
                options: .regularExpression
            )
            s = s.replacingOccurrences(
                of: #"\s*```$"#, with: "",
                options: .regularExpression
            )
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
    }

    /// Try to parse cleaned JSON; if it fails, attempt simple truncation repair.
    /// Returns nil only if repair is impossible.
    static func repair(_ raw: String) -> Data? {
        let cleaned = clean(raw)

        if let data = cleaned.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil {
            return data
        }

        // Attempt truncation repair
        var repaired = cleaned

        // Balance open string quotes
        let quoteCount = repaired.filter { $0 == "\"" }.count
        if quoteCount % 2 != 0 { repaired += "\"" }

        // Remove trailing comma before we close structures
        repaired = repaired.replacingOccurrences(
            of: #",\s*$"#, with: "", options: .regularExpression
        )

        // Count unmatched open brackets/braces
        var opens: [Character] = []
        var inString = false
        var prev: Character = "\0"
        for ch in repaired {
            if ch == "\"" && prev != "\\" { inString.toggle() }
            if !inString {
                switch ch {
                case "{": opens.append("}")
                case "[": opens.append("]")
                case "}", "]": _ = opens.popLast()
                default: break
                }
            }
            prev = ch
        }
        repaired += String(opens.reversed())

        return repaired.data(using: .utf8)
            .flatMap { data in
                (try? JSONSerialization.jsonObject(with: data)) != nil ? data : nil
            }
    }
}
