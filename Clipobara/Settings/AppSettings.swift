import Foundation
import Observation

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    private enum Key {
        static let isMonitoringEnabled = "isMonitoringEnabled"
        static let maximumItemCount = "maximumItemCount"
        static let maximumStorageBytes = "maximumStorageBytes"
        static let excludedBundleIdentifiers = "excludedBundleIdentifiers"
        static let shortcutKeyCode = "shortcutKeyCode"
        static let shortcutModifiers = "shortcutModifiers"
        static let moveSelectedClipToFront = "moveSelectedClipToFront"
        static let autoPasteOnSelect = "autoPasteOnSelect"
    }

    private let defaults: UserDefaults

    var isMonitoringEnabled: Bool {
        didSet { defaults.set(isMonitoringEnabled, forKey: Key.isMonitoringEnabled) }
    }

    var maximumItemCount: Int {
        didSet { defaults.set(maximumItemCount, forKey: Key.maximumItemCount) }
    }

    var maximumStorageBytes: Int {
        didSet { defaults.set(maximumStorageBytes, forKey: Key.maximumStorageBytes) }
    }

    var moveSelectedClipToFront: Bool {
        didSet { defaults.set(moveSelectedClipToFront, forKey: Key.moveSelectedClipToFront) }
    }

    var autoPasteOnSelect: Bool {
        didSet { defaults.set(autoPasteOnSelect, forKey: Key.autoPasteOnSelect) }
    }

    var excludedBundleIdentifiers: Set<String> {
        didSet {
            defaults.set(Array(excludedBundleIdentifiers).sorted(), forKey: Key.excludedBundleIdentifiers)
        }
    }

    private(set) var historyShortcut: GlobalShortcut

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.isMonitoringEnabled: true,
            Key.maximumItemCount: 500,
            Key.maximumStorageBytes: 512 * 1_024 * 1_024,
            Key.moveSelectedClipToFront: true,
            Key.autoPasteOnSelect: false,
            Key.shortcutKeyCode: Int(GlobalShortcut.default.keyCode),
            Key.shortcutModifiers: Int(GlobalShortcut.default.carbonModifiers),
            Key.excludedBundleIdentifiers: [
                "com.1password.1password",
                "com.agilebits.onepassword7",
                "com.bitwarden.desktop",
                "com.lastpass.LastPass"
            ]
        ])
        isMonitoringEnabled = defaults.bool(forKey: Key.isMonitoringEnabled)
        maximumItemCount = defaults.integer(forKey: Key.maximumItemCount)
        maximumStorageBytes = defaults.integer(forKey: Key.maximumStorageBytes)
        moveSelectedClipToFront = defaults.bool(forKey: Key.moveSelectedClipToFront)
        autoPasteOnSelect = defaults.bool(forKey: Key.autoPasteOnSelect)
        excludedBundleIdentifiers = Set(
            defaults.stringArray(forKey: Key.excludedBundleIdentifiers) ?? []
        )
        historyShortcut = GlobalShortcut(
            keyCode: UInt32(defaults.integer(forKey: Key.shortcutKeyCode)),
            carbonModifiers: UInt32(defaults.integer(forKey: Key.shortcutModifiers))
        )
    }

    func isExcluded(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return excludedBundleIdentifiers.contains(bundleIdentifier)
    }

    func setHistoryShortcut(_ shortcut: GlobalShortcut) {
        historyShortcut = shortcut
        defaults.set(Int(shortcut.keyCode), forKey: Key.shortcutKeyCode)
        defaults.set(Int(shortcut.carbonModifiers), forKey: Key.shortcutModifiers)
    }
}
