import AppKit
import ServiceManagement
import SwiftUI

struct MenuBarView: View {
    @Bindable var repository: ClipboardRepository
    @Bindable var settings: AppSettings
    let showHistory: () -> Void

    @State private var launchStatusRefresh = false

    var body: some View {
        Button("Show Clipboard History", systemImage: "clock.arrow.circlepath") {
            showHistory()
        }

        Divider()

        Toggle("Monitor Clipboard", isOn: $settings.isMonitoringEnabled)

        Button(
            SMAppService.mainApp.status == .enabled
                ? "Disable Launch at Login"
                : "Launch at Login",
            systemImage: "power"
        ) {
            toggleLaunchAtLogin()
        }
        .id(launchStatusRefresh)

        Divider()

        Button("Clear History…", systemImage: "trash", role: .destructive) {
            confirmClearHistory()
        }
        .disabled(repository.items.isEmpty)

        Button {
            NotificationCenter.default.post(name: .openClipobaraSettings, object: nil)
        } label: {
            Label("Settings…", systemImage: "gearshape")
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Clipobara", systemImage: "power.circle") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }

    private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            launchStatusRefresh.toggle()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    private func confirmClearHistory() {
        let alert = NSAlert()
        alert.messageText = "Clear clipboard history?"
        alert.informativeText = "All saved clipboard items and their local payloads will be deleted."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        repository.clearAll()
    }
}
