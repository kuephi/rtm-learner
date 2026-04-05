import SwiftUI

@main
struct RTMLearnerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No WindowGroup — this is a menubar-only app.
        // All windows are created programmatically by AppDelegate.
        SwiftUI.Settings { EmptyView() }
    }
}
