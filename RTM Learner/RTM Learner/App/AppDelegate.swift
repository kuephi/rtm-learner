import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    let settings = Settings()
    lazy var appLog: AppLog = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RTMLearner")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return AppLog(logFileURL: dir.appendingPathComponent("rtm-learner.log"))
    }()

    private var menubarController: MenubarController?
    private var preferencesController: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menubarController = MenubarController(
            settings: settings,
            appLog: appLog,
            runPipeline: { [weak self] in
                Task { @MainActor in await self?.runPipeline() }
            },
            openPreferences: { [weak self] in self?.openPreferences() }
        )

        Task { @MainActor in
            ScheduleManager.shared.onFire = { [weak self] in
                await self?.runPipeline()
            }
            ScheduleManager.shared.start(
                schedule: settings.schedule,
                lastRunDate: await StateManager.shared.lastRunDate
            )
        }

        if ProcessInfo.processInfo.arguments.contains("--uitesting") {
            openPreferences()
        }
    }

    func openPreferences() {
        if preferencesController == nil {
            preferencesController = PreferencesWindowController(settings: settings, appLog: appLog)
        }
        preferencesController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    func runPipeline() async {
        appLog.isPipelineRunning = true
        defer { appLog.isPipelineRunning = false }
        appLog.append("Pipeline started…")

        guard let sessionCookie = try? KeychainHelper.load(for: "substack_session") else {
            appLog.append("Pipeline failed: Substack session cookie missing. Add it in Preferences → Auth.")
            return
        }

        let provider: LLMProvider
        do {
            provider = try ProviderFactory.make(settings: settings, http: Self.llmSession)
        } catch {
            appLog.append("Pipeline failed: \(error.localizedDescription)")
            return
        }

        appLog.append("Provider: \(settings.providerType.displayName), model: \(settings.activeModel())")

        let outputDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RTMLearner")
        let iCloudDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/RTM")

        let orchestrator = PipelineOrchestrator(
            sessionCookie: sessionCookie,
            provider: provider,
            stateManager: StateManager.shared,
            http: URLSession.shared,
            feedURL: URL(string: "https://www.realtimemandarin.com/feed")!,
            outputDir: outputDir,
            iCloudDir: iCloudDir
        )
        await orchestrator.run { [weak self] msg in self?.appLog.append(msg) }
    }

    // URLSession with a 5-minute timeout for LLM requests (default is 60 s, too short).
    private static let llmSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 300
        config.timeoutIntervalForResource = 600
        return URLSession(configuration: config)
    }()
}
