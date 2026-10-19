import AppKit
import Carbon.HIToolbox

/// Registers global shortcuts via the Carbon hot key API (no Accessibility permission required).
final class HotKeyManager {
    static let shared = HotKeyManager()
    static let captureID: UInt32 = 1
    static let fullScreenID: UInt32 = 2

    var onTrigger: ((UInt32) -> Void)?
    private var refs: [EventHotKeyRef] = []
    private var handlerInstalled = false

    /// Re-registers all hotkeys from the current UserDefaults values.
    func registerFromSettings() {
        unregisterAll()
        installHandlerIfNeeded()
        let d = UserDefaults.standard
        register(id: Self.captureID, keyCode: d.integer(forKey: Prefs.captureKeyCode), modifiers: d.integer(forKey: Prefs.captureModifiers))
        if d.bool(forKey: Prefs.fullHotKeyEnabled) {
            register(id: Self.fullScreenID, keyCode: d.integer(forKey: Prefs.fullKeyCode), modifiers: d.integer(forKey: Prefs.fullModifiers))
        }
    }

    func unregisterAll() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
    }

    fileprivate func fire(_ id: UInt32) {
        onTrigger?(id)
    }

    private func register(id: UInt32, keyCode: Int, modifiers: Int) {
        var ref: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x53544752), id: id) // 'STGR'
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref { refs.append(ref) }
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), hotKeyCallback, 1, &spec, nil, nil)
        handlerInstalled = status == noErr
    }

    /// Converts AppKit modifier flags to Carbon modifier bits.
    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        var result = 0
        if flags.contains(.command) { result |= cmdKey }
        if flags.contains(.shift) { result |= shiftKey }
        if flags.contains(.option) { result |= optionKey }
        if flags.contains(.control) { result |= controlKey }
        return result
    }

    /// Human-readable label such as "⇧⌘2".
    static func describe(_ event: NSEvent) -> String {
        let f = event.modifierFlags
        var s = ""
        if f.contains(.control) { s += "⌃" }
        if f.contains(.option) { s += "⌥" }
        if f.contains(.shift) { s += "⇧" }
        if f.contains(.command) { s += "⌘" }
        let key = event.charactersIgnoringModifiers?.uppercased() ?? ""
        return s + (key.isEmpty || key == " " ? "Key \(event.keyCode)" : key)
    }
}

private func hotKeyCallback(_ next: EventHandlerCallRef?, _ event: EventRef?, _ userData: UnsafeMutableRawPointer?) -> OSStatus {
    guard let event else { return OSStatus(eventNotHandledErr) }
    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                   nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
    guard status == noErr else { return status }
    DispatchQueue.main.async { HotKeyManager.shared.fire(hotKeyID.id) }
    return noErr
}
