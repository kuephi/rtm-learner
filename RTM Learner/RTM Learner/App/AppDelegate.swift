import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {

    let settings = Settings()
    let appLog = AppLog()
    private var menubarController: MenubarController?
    private var preferencesController: PreferencesWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menubarController = MenubarController(
            settings: settings,
            appLog: appLog,
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
        guard let sessionCookie = try? KeychainHelper.load(for: "substack_session") else {
            appLog.append("Pipeline failed: Substack session cookie missing. Add it in Preferences → Auth.")
            return
        }

        let provider: LLMProvider
        do {
            provider = try ProviderFactory.make(settings: settings)
        } catch {
            appLog.append("Pipeline failed: \(error.localizedDescription)")
            return
        }

        let outputDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RTMLearner")
        let iCloudDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/RTM")

        let stateManager = StateManager.shared
        let http: HTTPClient = URLSession.shared

        do {
            let entries = try await Fetcher.fetchNewEntries(stateManager: stateManager)
            if entries.isEmpty {
                appLog.append("No new 中级 episodes found.")
                return
            }
            for entry in entries {
                appLog.append("\n→ Episode #\(entry.episode): \(entry.title)")
                let pageURL = URL(string: entry.url)!
                let html = try await Fetcher.downloadPage(url: pageURL, sessionCookie: sessionCookie, http: http)
                try await PipelineRunner.run(
                    entry: entry, html: html,
                    provider: provider,
                    stateManager: stateManager,
                    outputDir: outputDir,
                    iCloudDir: iCloudDir,
                    log: { [weak self] msg in self?.appLog.append(msg) }
                )
            }
        } catch {
            appLog.append("Pipeline error: \(error.localizedDescription)")
        }
    }
}
