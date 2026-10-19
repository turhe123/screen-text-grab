import SwiftUI
import AppKit
import ServiceManagement

/// The Settings window content: hotkeys, recognition options, feedback and launch at login.
struct SettingsView: View {
    @AppStorage(Prefs.accurate) private var accurate = true
    @AppStorage(Prefs.languages) private var languages = "en-US"
    @AppStorage(Prefs.autoDetectLanguage) private var autoDetect = true
    @AppStorage(Prefs.joinLines) private var joinLines = false
    @AppStorage(Prefs.trimWhitespace) private var trim = true
    @AppStorage(Prefs.playSound) private var playSound = true
    @AppStorage(Prefs.showNotifications) private var notifications = true
    @AppStorage(Prefs.rotateRetry) private var rotateRetry = true
    @AppStorage(Prefs.barcodeMode) private var barcodeMode = false
    @AppStorage(Prefs.fullHotKeyEnabled) private var fullEnabled = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    private let supported = TextRecognizer.supportedLanguages()

    var body: some View {
        Form {
            Section("Shortcuts") {
                LabeledContent("Capture Text") {
                    HotKeyRecorder(keyCodeKey: Prefs.captureKeyCode, modifiersKey: Prefs.captureModifiers, labelKey: Prefs.captureHotKeyLabel)
                }
                Toggle("Enable full-screen shortcut", isOn: $fullEnabled)
                    .onChange(of: fullEnabled) { HotKeyManager.shared.registerFromSettings() }
                if fullEnabled {
                    LabeledContent("Capture Full Screen") {
                        HotKeyRecorder(keyCodeKey: Prefs.fullKeyCode, modifiersKey: Prefs.fullModifiers, labelKey: Prefs.fullHotKeyLabel)
                    }
                }
            }
            Section("Recognition") {
                Picker("Recognition level", selection: $accurate) {
                    Text("Accurate").tag(true)
                    Text("Fast").tag(false)
                }
                Toggle("Detect language automatically", isOn: $autoDetect)
                Toggle("Join lines (remove line breaks)", isOn: $joinLines)
                Toggle("Trim whitespace", isOn: $trim)
                Toggle("Retry rotated 90° when no text is found", isOn: $rotateRetry)
                Toggle("Read QR codes and barcodes", isOn: $barcodeMode)
            }
            Section("Languages") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(supported, id: \.self) { code in
                            Toggle(Self.displayName(code), isOn: binding(for: code))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 130)
            }
            Section("General") {
                Toggle("Play sound", isOn: $playSound)
                Toggle("Show notifications", isOn: $notifications)
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { setLaunchAtLogin(launchAtLogin) }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
            }
            Section {
                HStack {
                    Text("ScreenTextGrab is free and open source.").foregroundStyle(.secondary)
                    Spacer()
                    Button("Support / Donate ❤️") { Support.open() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 620)
    }

    private func binding(for code: String) -> Binding<Bool> {
        Binding(
            get: { Prefs.selectedLanguages.contains(code) },
            set: { on in
                var set = Prefs.selectedLanguages.filter { $0 != code }
                if on { set.append(code) }
                languages = set.joined(separator: ",")
            })
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Could not update login item: \(error.localizedDescription)"
        }
    }

    private static func displayName(_ code: String) -> String {
        let name = Locale.current.localizedString(forIdentifier: code) ?? code
        return "\(name) (\(code))"
    }
}

/// A button that records the next key combination (with at least one modifier) as a global hotkey.
struct HotKeyRecorder: View {
    let keyCodeKey: String
    let modifiersKey: String
    let labelKey: String
    @AppStorage private var label: String
    @State private var recording = false
    @State private var monitor: Any?

    init(keyCodeKey: String, modifiersKey: String, labelKey: String) {
        self.keyCodeKey = keyCodeKey
        self.modifiersKey = modifiersKey
        self.labelKey = labelKey
        _label = AppStorage(wrappedValue: "", labelKey)
    }

    var body: some View {
        Button(recording ? "Type shortcut…" : label) { recording ? stop() : start() }
            .frame(minWidth: 120)
    }

    private func start() {
        recording = true
        HotKeyManager.shared.unregisterAll()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil }   // Escape cancels recording
            let carbon = HotKeyManager.carbonModifiers(event.modifierFlags)
            guard carbon != 0 else { NSSound.beep(); return nil }
            UserDefaults.standard.set(Int(event.keyCode), forKey: keyCodeKey)
            UserDefaults.standard.set(carbon, forKey: modifiersKey)
            label = HotKeyManager.describe(event)
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        HotKeyManager.shared.registerFromSettings()
    }
}

/// Hosts SwiftUI content in a plain AppKit window, since a menu-bar app has no regular windows.
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?

    static func show() {
        window = present(window, title: "ScreenTextGrab Settings", content: SettingsView())
    }

    static func present<V: View>(_ existing: NSWindow?, title: String, content: V) -> NSWindow {
        let win = existing ?? {
            let w = NSWindow(contentViewController: NSHostingController(rootView: content))
            w.title = title
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            return w
        }()
        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
        return win
    }
}

/// Explains why Screen Recording permission is needed and links to System Settings.
struct PermissionView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Screen Recording permission needed", systemImage: "lock.shield")
                .font(.headline)
            Text("ScreenTextGrab reads text from the pixels inside the box you draw. macOS requires Screen Recording permission for that. Images are processed on-device and never saved or sent anywhere.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Enable ScreenTextGrab in Privacy & Security › Screen & System Audio Recording, then quit and reopen the app.")
                .font(.callout).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Open Privacy & Security") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 420)
    }
}

/// Presents the single shared permission explanation window.
@MainActor
enum PermissionWindow {
    private static var window: NSWindow?

    static func show() {
        window = SettingsWindow.present(window, title: "Permission Required", content: PermissionView())
    }
}
