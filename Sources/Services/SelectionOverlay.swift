import AppKit

/// A finished selection in display-local, top-left-origin points.
struct Selection {
    let rect: CGRect
    let displayID: CGDirectDisplayID
    let scale: CGFloat
}

/// Shows one dimmed, borderless overlay per screen and reports the dragged rectangle.
@MainActor
final class SelectionOverlayController {
    private var windows: [NSWindow] = []
    private var completion: ((Selection?) -> Void)?
    private var spaceObserver: NSObjectProtocol?

    var isActive: Bool { !windows.isEmpty }

    func begin(completion: @escaping (Selection?) -> Void) {
        self.completion = completion
        for screen in NSScreen.screens {
            let window = OverlayWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
            window.level = .screenSaver
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            let view = OverlayView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.onFinish = { [weak self, weak screen] rect in
                guard let self else { return }
                guard let rect, let screen, let id = screen.displayID else { return self.finish(nil) }
                let flipped = CGRect(x: rect.minX, y: screen.frame.height - rect.maxY, width: rect.width, height: rect.height)
                self.finish(Selection(rect: flipped, displayID: id, scale: screen.backingScaleFactor))
            }
            window.contentView = view
            window.setFrame(screen.frame, display: true)
            windows.append(window)
        }
        NSApp.activate(ignoringOtherApps: true)
        windows.forEach { $0.orderFrontRegardless() }
        // Prefer the screen under the pointer for key focus (Escape handling).
        let mouse = NSEvent.mouseLocation
        (windows.first { $0.frame.contains(mouse) } ?? windows.first)?.makeKey()
        NSCursor.crosshair.push()
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.finish(nil) }
        }
    }

    private func finish(_ selection: Selection?) {
        guard isActive else { return }
        NSCursor.pop()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        if let spaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(spaceObserver) }
        spaceObserver = nil
        let done = completion
        completion = nil
        done?(selection)
    }
}

/// Borderless window that can take key focus so Escape reaches it.
private final class OverlayWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// Draws the dim layer, the selection rectangle and a size readout; tracks the drag.
private final class OverlayView: NSView {
    var onFinish: ((CGRect?) -> Void)?
    private var start: CGPoint?
    private var current: CGPoint?

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func viewDidMoveToWindow() { window?.makeFirstResponder(self) }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    private var selection: CGRect? {
        guard let start, let current else { return nil }
        return CGRect(x: min(start.x, current.x), y: min(start.y, current.y),
                      width: abs(start.x - current.x), height: abs(start.y - current.y)).integral
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        current = start
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        current = convert(event.locationInWindow, from: nil)
        guard let rect = selection, rect.width >= 10, rect.height >= 10 else {
            // Too small: ignore and let the user try again.
            start = nil; current = nil; needsDisplay = true
            return
        }
        onFinish?(rect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { onFinish?(nil) } else { super.keyDown(with: event) }
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.35).setFill()
        bounds.fill()
        guard let rect = selection else { return }
        NSColor.clear.setFill()
        rect.fill(using: .copy)
        NSColor.white.setStroke()
        let path = NSBezierPath(rect: rect.insetBy(dx: 0.5, dy: 0.5))
        path.lineWidth = 1
        path.stroke()

        let label = "\(Int(rect.width)) × \(Int(rect.height))" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = label.size(withAttributes: attrs)
        var origin = CGPoint(x: rect.maxX - size.width - 8, y: rect.minY - size.height - 8)
        if origin.y < 0 { origin.y = rect.minY + 4 }
        let bg = CGRect(x: origin.x - 4, y: origin.y - 2, width: size.width + 8, height: size.height + 4)
        NSColor.black.withAlphaComponent(0.7).setFill()
        NSBezierPath(roundedRect: bg, xRadius: 4, yRadius: 4).fill()
        label.draw(at: origin, withAttributes: attrs)
    }
}
