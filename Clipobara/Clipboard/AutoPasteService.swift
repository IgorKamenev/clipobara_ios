import AppKit
import Carbon
import CoreGraphics
import Foundation

enum AutoPasteService {
    /// Shows the system accessibility dialog and adds the app to the
    /// Accessibility list in System Settings. AX trust also authorizes
    /// posting CGEvents, and unlike CGRequestPostEventAccess it reliably
    /// materializes the list entry the user can toggle.
    @discardableResult
    static func requestAccessibilityAccess() -> Bool {
        // Literal value of kAXTrustedCheckOptionPrompt; the imported global
        // is a `var` and not concurrency-safe under Swift 6.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static var isTrusted: Bool {
        AXIsProcessTrusted() || CGPreflightPostEventAccess()
    }

    /// The system prompt is only shown once per app; after that the user has to
    /// flip the checkbox in System Settings themselves.
    static func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    @discardableResult
    static func paste() -> Bool {
        guard isTrusted || requestAccessibilityAccess() else {
            return false
        }

        let source = CGEventSource(stateID: .combinedSessionState)
        source?.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let keyCode = CGKeyCode(kVK_ANSI_V)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cgSessionEventTap)
        keyUp.post(tap: .cgSessionEventTap)
        return true
    }
}
