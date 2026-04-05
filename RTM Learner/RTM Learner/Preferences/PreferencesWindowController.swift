import AppKit
import SwiftUI

final class PreferencesWindowController: NSWindowController {
    private let settings: Settings
    private let appLog: AppLog

    init(settings: Settings, appLog: AppLog) {
        self.settings = settings
        self.appLog = appLog
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "RTM Learner Preferences"
        window.center()
        window.contentView = NSHostingView(rootView: PreferencesView(settings: settings, appLog: appLog))
        super.init(window: window)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        super.showWindow(sender)
        window?.makeKeyAndOrderFront(sender)
    }
}
