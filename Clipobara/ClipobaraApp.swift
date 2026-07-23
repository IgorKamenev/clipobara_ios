import SwiftUI

@main
struct ClipobaraApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    
    
    
    var body: some Scene {
        Window("Clipobara Settings Bridge", id: "settings-bridge") {
            SettingsWindowBridge()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 100, height: 100)

        MenuBarExtra("Clipobara", systemImage: "clipboard.fill") {
            MenuBarView(
                repository: AppController.shared.repository,
                settings: AppController.shared.settings,
                showHistory: AppController.shared.historyPanelController.show
            )
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView(
                settings: AppController.shared.settings,
                repository: AppController.shared.repository,
                onShortcutChange: AppController.shared.updateHistoryShortcut
            )
            .onDisappear {
                NotificationCenter.default.post(name: .clipobaraSettingsClosed, object: nil)
            }
        }
    }
}
