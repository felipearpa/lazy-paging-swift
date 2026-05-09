import SwiftUI
import AppKit
import LazyPagingShowcase

@main
struct LazyPagingShowcaseAppMain: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ShowcaseScreen()
                .frame(minWidth: 420, minHeight: 600)
        }
    }
}

/// Forces the unbundled `swift run`-launched app to behave as a regular
/// foreground app so its window opens in front of Xcode instead of staying
/// behind it as an accessory process.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
