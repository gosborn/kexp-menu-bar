import SwiftUI

@main
struct KEXPMenuBarApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        // The menu bar item lives in StatusBarController; SwiftUI just needs a scene.
        Settings { EmptyView() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // LSUIElement covers the bundled app; this keeps `swift run` / Xcode runs out of the Dock too.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBar = StatusBarController(radio: Radio(), likes: Likes())
    }
}
