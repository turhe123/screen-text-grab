import Foundation
import Carbon.HIToolbox

/// UserDefaults keys and defaults shared by `@AppStorage` views and services.
enum Prefs {
    static let accurate = "recognitionAccurate"
    static let languages = "recognitionLanguages"          // comma-separated BCP-47 codes
    static let autoDetectLanguage = "autoDetectLanguage"
    static let joinLines = "joinLines"
    static let trimWhitespace = "trimWhitespace"
    static let playSound = "playSound"
    static let showNotifications = "showNotifications"
    static let rotateRetry = "rotateRetry"
    static let barcodeMode = "barcodeMode"
    static let captureKeyCode = "captureKeyCode"
    static let captureModifiers = "captureModifiers"
    static let captureHotKeyLabel = "captureHotKeyLabel"
    static let fullKeyCode = "fullKeyCode"
    static let fullModifiers = "fullModifiers"
    static let fullHotKeyLabel = "fullHotKeyLabel"
    static let fullHotKeyEnabled = "fullHotKeyEnabled"

    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            accurate: true,
            languages: "en-US",
            autoDetectLanguage: true,
            joinLines: false,
            trimWhitespace: true,
            playSound: true,
            showNotifications: true,
            rotateRetry: true,
            barcodeMode: false,
            captureKeyCode: kVK_ANSI_2,
            captureModifiers: cmdKey | shiftKey,
            captureHotKeyLabel: "⇧⌘2",
            fullKeyCode: kVK_ANSI_9,
            fullModifiers: cmdKey | shiftKey,
            fullHotKeyLabel: "⇧⌘9",
            fullHotKeyEnabled: false,
        ])
    }

    static var selectedLanguages: [String] {
        (UserDefaults.standard.string(forKey: languages) ?? "")
            .split(separator: ",").map { String($0) }.filter { !$0.isEmpty }
    }
}
