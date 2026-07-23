import AppKit
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    let shortcut: GlobalShortcut
    let onChange: (GlobalShortcut) -> Void

    func makeNSView(context: Context) -> ShortcutRecorderControl {
        let control = ShortcutRecorderControl()
        control.shortcut = shortcut
        control.onChange = onChange
        return control
    }

    func updateNSView(_ control: ShortcutRecorderControl, context: Context) {
        if !control.isRecording {
            control.shortcut = shortcut
        }
        control.onChange = onChange
        control.needsDisplay = true
    }
}

@MainActor
final class ShortcutRecorderControl: NSControl {
    var shortcut: GlobalShortcut = .default
    var onChange: ((GlobalShortcut) -> Void)?
    private(set) var isRecording = false

    override var acceptsFirstResponder: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: 190, height: 30) }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            finishRecording()
            return
        }
        guard let newShortcut = GlobalShortcut(event: event) else {
            NSSound.beep()
            return
        }
        shortcut = newShortcut
        onChange?(newShortcut)
        finishRecording()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording, event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }
        keyDown(with: event)
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return super.resignFirstResponder()
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let drawingBounds = bounds.insetBy(dx: 1, dy: 1)
        let path = NSBezierPath(roundedRect: drawingBounds, xRadius: 6, yRadius: 6)
        (isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.18) : .controlBackgroundColor)
            .setFill()
        path.fill()
        (isRecording ? NSColor.controlAccentColor : .separatorColor).setStroke()
        path.lineWidth = isRecording ? 2 : 1
        path.stroke()

        let title = isRecording ? "Press a shortcut…" : shortcut.displayName
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.labelColor
        ]
        let size = title.size(withAttributes: attributes)
        title.draw(
            at: NSPoint(
                x: bounds.midX - size.width / 2,
                y: bounds.midY - size.height / 2
            ),
            withAttributes: attributes
        )
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }

    private func finishRecording() {
        isRecording = false
        window?.makeFirstResponder(nil)
        needsDisplay = true
    }
}
