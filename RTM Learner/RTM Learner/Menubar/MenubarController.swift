import AppKit
import SwiftUI

@MainActor
final class MenubarController {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private let settings: Settings
    private let appLog: AppLog
    private let runPipeline: () -> Void
    private let openPreferences: () -> Void

    init(settings: Settings, appLog: AppLog,
         runPipeline: @escaping () -> Void,
         openPreferences: @escaping () -> Void) {
        self.settings = settings
        self.appLog = appLog
        self.runPipeline = runPipeline
        self.openPreferences = openPreferences
        setupStatusItem()
        setupPopover()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "RTM"
            button.action = #selector(togglePopover)
            button.target = self
        }
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 260, height: 280)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: MenubarPopoverView(
                settings: settings,
                appLog: appLog,
                onRunNow: { [weak self] in self?.runPipeline() },
                onShowLog: { [weak self] in self?.openPreferences() },
                onPreferences: { [weak self] in self?.openPreferences() }
            )
        )
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
