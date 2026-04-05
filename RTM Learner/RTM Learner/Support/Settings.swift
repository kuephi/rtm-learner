import Foundation
import Observation

/// `@Observable` only tracks *stored* properties. All Settings properties are stored
/// here and persisted to UserDefaults via `didSet`, so SwiftUI views re-render on mutation.
@Observable
final class Settings {
    private let defaults: UserDefaults

    var schedule: ScheduleConfig {
        didSet {
            let data = try? JSONEncoder().encode(schedule)
            defaults.set(data, forKey: "schedule")
        }
    }

    var providerType: LLMProviderType {
        didSet { defaults.set(providerType.rawValue, forKey: "providerType") }
    }

    var claudeModel: String {
        didSet { defaults.set(claudeModel, forKey: "claudeModel") }
    }

    var geminiModel: String {
        didSet { defaults.set(geminiModel, forKey: "geminiModel") }
    }

    var openAIModel: String {
        didSet { defaults.set(openAIModel, forKey: "openAIModel") }
    }

    var openRouterModel: String {
        didSet { defaults.set(openRouterModel, forKey: "openRouterModel") }
    }

    var lastRunDate: Date? {
        didSet {
            defaults.set(lastRunDate?.timeIntervalSince1970 ?? 0, forKey: "lastRunDate")
        }
    }

    init(suiteName: String? = nil) {
        if let name = suiteName {
            defaults = UserDefaults(suiteName: name)!
        } else {
            defaults = .standard
        }

        if let data = defaults.data(forKey: "schedule"),
           let config = try? JSONDecoder().decode(ScheduleConfig.self, from: data) {
            schedule = config
        } else {
            schedule = .defaultConfig
        }

        let rawProvider = defaults.string(forKey: "providerType") ?? LLMProviderType.claude.rawValue
        providerType = LLMProviderType(rawValue: rawProvider) ?? .claude

        claudeModel     = defaults.string(forKey: "claudeModel")     ?? ""
        geminiModel     = defaults.string(forKey: "geminiModel")     ?? ""
        openAIModel     = defaults.string(forKey: "openAIModel")     ?? ""
        openRouterModel = defaults.string(forKey: "openRouterModel") ?? ""

        let t = defaults.double(forKey: "lastRunDate")
        lastRunDate = t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    /// Returns the model to use for the current provider, falling back to the provider default.
    func activeModel() -> String {
        switch providerType {
        case .claude:
            let m = claudeModel.trimmingCharacters(in: .whitespaces)
            return m.isEmpty ? "claude-sonnet-4-6" : m
        case .gemini:
            let m = geminiModel.trimmingCharacters(in: .whitespaces)
            return m.isEmpty ? "gemini-2.0-flash" : m
        case .openai:
            let m = openAIModel.trimmingCharacters(in: .whitespaces)
            return m.isEmpty ? "gpt-4o" : m
        case .openrouter:
            return openRouterModel
        }
    }
}
