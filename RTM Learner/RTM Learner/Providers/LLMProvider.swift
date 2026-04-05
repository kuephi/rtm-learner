import Foundation

protocol LLMProvider {
    func complete(prompt: String) async throws -> String
}
