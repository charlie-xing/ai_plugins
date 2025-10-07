import SwiftUI
import AppKit

@main
struct ai_pluginsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.setActivationPolicy(.regular)

        // Test localization
        print("🌍 Localization test:")
        print("  - System language: \(Locale.preferredLanguages.first ?? "unknown")")
        print("  - NSLocalizedString(\"plugins\"): \(NSLocalizedString("plugins", bundle: .module, comment: ""))")
        print("  - NSLocalizedString(\"settings\"): \(NSLocalizedString("settings", bundle: .module, comment: ""))")

        // Test with Bundle.module
        #if SWIFT_PACKAGE
        let testString = NSLocalizedString("plugins", bundle: .module, comment: "")
        print("  - Bundle.module NSLocalizedString(\"plugins\"): \(testString)")
        #endif

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.setupWindow()
        }
    }

    @MainActor
    func setupWindow() {
        guard let window = NSApplication.shared.windows.first else {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                self.setupWindow()
            }
            return
        }

        self.window = window
        window.makeKeyAndOrderFront(nil)
        window.level = .normal
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            window?.makeKeyAndOrderFront(nil)
        }
        return true
    }
}
