import SwiftUI
import AppKit

/// The MenuBarExtra menu: capture actions, recent captures, settings, support and quit.
struct MenuContentView: View {
    @EnvironmentObject var controller: AppController
    @AppStorage(Prefs.captureHotKeyLabel) private var captureLabel = "⇧⌘2"
    @AppStorage(Prefs.fullHotKeyLabel) private var fullLabel = "⇧⌘9"
    @AppStorage(Prefs.fullHotKeyEnabled) private var fullEnabled = false

    var body: some View {
        Button("Capture Text  (\(captureLabel))") { controller.captureRegion() }
        Button(fullEnabled ? "Capture Full Screen  (\(fullLabel))" : "Capture Full Screen") { controller.captureFullScreen() }
        Divider()
        Menu("Recent Captures") {
            if controller.history.isEmpty {
                Text("Nothing captured yet")
            } else {
                ForEach(controller.history) { capture in
                    Button(Self.preview(capture.text)) { controller.recopy(capture) }
                }
            }
        }
        Divider()
        Button("Settings…") { SettingsWindow.show() }
            .keyboardShortcut(",")
        Button("Support / Donate ❤️") { Support.open() }
        Divider()
        Button("Quit ScreenTextGrab") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private static func preview(_ text: String) -> String {
        let flat = text.replacingOccurrences(of: "\n", with: " ")
        return flat.count > 50 ? String(flat.prefix(50)) + "…" : flat
    }
}

/// Opens the project's donation page.
enum Support {
    static func open() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
    }
}
