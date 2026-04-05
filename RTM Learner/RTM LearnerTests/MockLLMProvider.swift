import Foundation
@testable import RTM_Learner

final class MockLLMProvider: LLMProvider {
    var response: String = ""
    var error: Error?
    var callCount = 0
    var lastPrompt: String = ""

    func complete(prompt: String) async throws -> String {
        callCount += 1
        lastPrompt = prompt
        if let error { throw error }
        return response
    }
}
