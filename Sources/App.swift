import SwiftUI
import AppKit

/// Entry point: a menu-bar-only app (no Dock icon, see `LSUIElement`) exposing the capture menu.
@main
struct ScreenTextGrabApp: App {
    @StateObject private var controller = AppController.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView()
                .environmentObject(controller)
        } label: {
            Image(systemName: controller.isProcessing ? "hourglass" : "text.viewfinder")
        }
        .menuBarExtraStyle(.menu)
    }
}

/// Central coordinator: owns the capture flow, in-memory history and app-wide state.
@MainActor
final class AppController: ObservableObject {
    static let shared = AppController()

    /// Ephemeral history entry; lives in memory only and is never persisted.
    struct Capture: Identifiable {
        let id = UUID()
        let text: String
        let date = Date()
    }

    @Published private(set) var isProcessing = false
    @Published private(set) var history: [Capture] = []
    private let overlay = SelectionOverlayController()

    private init() {
        Prefs.registerDefaults()
        Notifier.requestAuthorizationIfNeeded()
        HotKeyManager.shared.onTrigger = { [weak self] id in
            switch id {
            case HotKeyManager.captureID: self?.captureRegion()
            case HotKeyManager.fullScreenID: self?.captureFullScreen()
            default: break
            }
        }
        HotKeyManager.shared.registerFromSettings()
    }

    /// Starts interactive region selection on every screen.
    func captureRegion() {
        guard !isProcessing, !overlay.isActive, ensurePermission() else { return }
        overlay.begin { [weak self] selection in
            guard let self, let selection else { return }
            self.process(rect: selection.rect, displayID: selection.displayID, scale: selection.scale)
        }
    }

    /// Captures the whole main display.
    func captureFullScreen() {
        guard !isProcessing, !overlay.isActive, ensurePermission() else { return }
        guard let screen = NSScreen.screens.first, let id = screen.displayID else { return }
        process(rect: CGRect(origin: .zero, size: screen.frame.size), displayID: id, scale: screen.backingScaleFactor)
    }

    /// Copies a history entry back onto the clipboard.
    func recopy(_ capture: Capture) {
        Clipboard.write(capture.text)
    }

    private func ensurePermission() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        CGRequestScreenCaptureAccess()
        PermissionWindow.show()
        return false
    }

    private func process(rect: CGRect, displayID: CGDirectDisplayID, scale: CGFloat) {
        isProcessing = true
        Task {
            defer { isProcessing = false }
            do {
                let result = try await TextRecognizer.captureAndRecognize(rect: rect, displayID: displayID, scale: scale)
                finish(with: result)
            } catch {
                Notifier.post(title: "Capture failed", body: error.localizedDescription)
            }
        }
    }

    private func finish(with text: String?) {
        let defaults = UserDefaults.standard
        guard let text, !text.isEmpty else {
            Notifier.post(title: "No text found", body: "The clipboard was left untouched.")
            return
        }
        Clipboard.write(text)
        history.insert(Capture(text: text), at: 0)
        if history.count > 20 { history.removeLast(history.count - 20) }
        if defaults.bool(forKey: Prefs.playSound) { NSSound(named: "Tink")?.play() }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? text
        Notifier.post(title: "Copied text", body: String(firstLine.prefix(120)))
    }
}

/// Thin wrapper around the general pasteboard.
enum Clipboard {
    static func write(_ text: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}

extension NSScreen {
    /// The CoreGraphics display ID backing this screen.
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }
}
