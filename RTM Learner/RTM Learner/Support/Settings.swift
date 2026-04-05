import Foundation
import Observation

@Observable
final class Settings {
    private let defaults: UserDefaults

    init(suiteName: String? = nil) {
        if let name = suiteName {
            defaults = UserDefaults(suiteName: name)!
        } else {
            defaults = .standard
        }
    }

    var schedule: ScheduleConfig {
        get {
            guard let data = defaults.data(forKey: "schedule"),
                  let config = try? JSONDecoder().decode(ScheduleConfig.self, from: data)
            else { return .defaultConfig }
            return config
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            defaults.set(data, forKey: "schedule")
        }
    }

    var providerType: LLMProviderType {
        get {
            let raw = defaults.string(forKey: "providerType") ?? LLMProviderType.claude.rawValue
            return LLMProviderType(rawValue: raw) ?? .claude
        }
        set { defaults.set(newValue.rawValue, forKey: "providerType") }
    }

    var claudeModel: String {
        get { defaults.string(forKey: "claudeModel") ?? "" }
        set { defaults.set(newValue, forKey: "claudeModel") }
    }

    var geminiModel: String {
        get { defaults.string(forKey: "geminiModel") ?? "" }
        set { defaults.set(newValue, forKey: "geminiModel") }
    }

    var openAIModel: String {
        get { defaults.string(forKey: "openAIModel") ?? "" }
        set { defaults.set(newValue, forKey: "openAIModel") }
    }

    var openRouterModel: String {
        get { defaults.string(forKey: "openRouterModel") ?? "" }
        set { defaults.set(newValue, forKey: "openRouterModel") }
    }

    var lastRunDate: Date? {
        get {
            let t = defaults.double(forKey: "lastRunDate")
            return t > 0 ? Date(timeIntervalSince1970: t) : nil
        }
        set {
            defaults.set(newValue?.timeIntervalSince1970 ?? 0, forKey: "lastRunDate")
        }
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
