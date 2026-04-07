import Foundation
import Observation

@Observable
final class AppLog {
    var text: String = ""
    var isPipelineRunning: Bool = false

    func append(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        text += "[\(timestamp)] \(message)\n"
    }

    func clear() {
        text = ""
    }
}
