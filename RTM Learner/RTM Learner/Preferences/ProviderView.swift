import SwiftUI

struct ProviderView: View {
    @Bindable var settings: Settings

    @State private var apiKey: String = ""
    @State private var openRouterModels: [OpenRouterProvider.Model] = []
    @State private var isFetchingModels = false
    @State private var modelFetchError: String? = nil

    var body: some View {
        Form {
            Section("LLM Provider") {
                Picker("Provider", selection: $settings.providerType) {
                    ForEach(LLMProviderType.allCases) { type in
                        Text(type.displayName).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: settings.providerType) { _, _ in loadApiKey() }
            }

            Section("API Key") {
                SecureField("API Key", text: $apiKey)
                    .onChange(of: apiKey) { _, newKey in saveApiKey(newKey) }
            }

            if settings.providerType == .openrouter {
                openRouterModelSection
            } else {
                Section("Model Override (optional)") {
                    TextField(
                        settings.providerType.defaultModel ?? "model-id",
                        text: modelOverrideBinding
                    )
                    .font(.system(.body, design: .monospaced))
                    Text("Leave blank to use the default: \(settings.providerType.defaultModel ?? "—")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear(perform: loadApiKey)
    }

    // MARK: - OpenRouter Model Section

    private var openRouterModelSection: some View {
        Section {
            if isFetchingModels {
                HStack { ProgressView(); Text("Fetching models…").foregroundStyle(.secondary) }
            } else if openRouterModels.isEmpty {
                if let error = modelFetchError {
                    VStack(alignment: .leading) {
                        Text(error).foregroundStyle(.red).font(.caption)
                        TextField("Model ID (e.g. anthropic/claude-sonnet-4-6)",
                                  text: $settings.openRouterModel)
                            .font(.system(.body, design: .monospaced))
                    }
                } else {
                    Button("Fetch available models") { Task { await fetchOpenRouterModels() } }
                }
            } else {
                Picker("Model", selection: $settings.openRouterModel) {
                    ForEach(openRouterModels) { model in
                        Text(model.name).tag(model.id)
                    }
                }
                Button("Refresh") { Task { await fetchOpenRouterModels() } }
            }
        } header: {
            Text("Model")
        }
    }

    // MARK: - Helpers

    private var modelOverrideBinding: Binding<String> {
        switch settings.providerType {
        case .claude:      return $settings.claudeModel
        case .gemini:      return $settings.geminiModel
        case .openai:      return $settings.openAIModel
        case .openrouter:  return $settings.openRouterModel
        }
    }

    private var keychainKey: String {
        "\(settings.providerType.rawValue)_api_key"
    }

    private func loadApiKey() {
        apiKey = (try? KeychainHelper.load(for: keychainKey)) ?? ""
        if settings.providerType == .openrouter && !apiKey.isEmpty && openRouterModels.isEmpty {
            Task { await fetchOpenRouterModels() }
        }
    }

    private func saveApiKey(_ key: String) {
        guard !key.isEmpty else { return }
        try? KeychainHelper.save(key, for: keychainKey)
    }

    private func fetchOpenRouterModels() async {
        guard let key = try? KeychainHelper.load(for: "openrouter_api_key") else {
            modelFetchError = "Enter your API key first."
            return
        }
        isFetchingModels = true
        modelFetchError = nil
        do {
            openRouterModels = try await OpenRouterProvider.fetchModels(apiKey: key)
            if settings.openRouterModel.isEmpty, let first = openRouterModels.first {
                settings.openRouterModel = first.id
            }
        } catch {
            modelFetchError = "Could not fetch models: \(error.localizedDescription)"
            openRouterModels = []
        }
        isFetchingModels = false
    }
}
