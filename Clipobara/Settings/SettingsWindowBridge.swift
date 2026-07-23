import AppKit
import SwiftUI

extension Notification.Name {
    static let openClipobaraSettings = Notification.Name("openClipobaraSettings")
    static let clipobaraSettingsClosed = Notification.Name("clipobaraSettingsClosed")
}

struct SettingsWindowBridge: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 100, height: 100)
            .background(BridgeWindowAccessor())
            .onReceive(NotificationCenter.default.publisher(for: .openClipobaraSettings)) { _ in
                openSettingsReliably()
            }
            .onReceive(NotificationCenter.default.publisher(for: .clipobaraSettingsClosed)) { _ in
                NSApp.setActivationPolicy(.accessory)
            }
    }

    private func openSettingsReliably() {
        Task { @MainActor in
            NSApp.setActivationPolicy(.regular)
            try? await Task.sleep(for: .milliseconds(100))
            NSApp.activate(ignoringOtherApps: true)
            openSettings()

            try? await Task.sleep(for: .milliseconds(200))
            if let settingsWindow = findSettingsWindow() {
                settingsWindow.alphaValue = 1
                settingsWindow.makeKeyAndOrderFront(nil)
                settingsWindow.orderFrontRegardless()
            }
        }
    }

    private func findSettingsWindow() -> NSWindow? {
        NSApp.windows.first { window in
            if window.identifier?.rawValue == "com.apple.SwiftUI.Settings" {
                return true
            }
            guard window.title != "Clipobara Settings Bridge" else { return false }
            if window.isVisible,
               window.styleMask.contains(.titled),
               (window.title.localizedCaseInsensitiveContains("settings")
                   || window.title.localizedCaseInsensitiveContains("preferences")) {
                return true
            }
            if let contentViewController = window.contentViewController,
               String(describing: type(of: contentViewController)).contains("Settings") {
                return true
            }
            return false
        }
    }
}

private struct BridgeWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { hideBridgeWindow(containing: view) }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DispatchQueue.main.async { hideBridgeWindow(containing: view) }
    }

    private func hideBridgeWindow(containing view: NSView) {
        guard let window = view.window else { return }
        window.alphaValue = 0
        window.ignoresMouseEvents = true
        window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
    }
}
