import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let repository: ClipboardRepository
    let onShortcutChange: (GlobalShortcut) -> String?
    @State private var newBundleIdentifier = ""
    @State private var shortcutError: String?

    var body: some View {
        Form {
            Section("Keyboard shortcut") {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Show clipboard history")
                        Text("Click the field, then press a shortcut with at least one modifier.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    ShortcutRecorderView(
                        shortcut: settings.historyShortcut,
                        onChange: updateShortcut
                    )
                    .frame(width: 190, height: 30)
                }
                if let shortcutError {
                    Text(shortcutError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                Button("Restore Default") {
                    updateShortcut(.default)
                }
                .disabled(settings.historyShortcut == .default)
            }

            Section("History") {
                Toggle("Monitor clipboard changes", isOn: $settings.isMonitoringEnabled)
                Toggle("Move selected clip to front", isOn: $settings.moveSelectedClipToFront)
                VStack(alignment: .leading, spacing: 4) {
                    Toggle(
                        "Paste automatically after selecting",
                        isOn: Binding(
                            get: { settings.autoPasteOnSelect },
                            set: { newValue in
                                settings.autoPasteOnSelect = newValue
                                if newValue, !AutoPasteService.requestAccessibilityAccess() {
                                    // No second system prompt will appear; send the
                                    // user straight to the Accessibility pane.
                                    AutoPasteService.openAccessibilitySettings()
                                }
                            }
                        )
                    )
                    Text("Requires keyboard control: in System Settings → Privacy & Security → Accessibility, click “+” and add Clipobara.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Stepper(
                    "Keep up to \(settings.maximumItemCount) items",
                    value: $settings.maximumItemCount,
                    in: 50...5_000,
                    step: 50
                )
                Picker("Maximum local storage", selection: $settings.maximumStorageBytes) {
                    Text("128 MB").tag(128 * 1_024 * 1_024)
                    Text("512 MB").tag(512 * 1_024 * 1_024)
                    Text("1 GB").tag(1_024 * 1_024 * 1_024)
                    Text("2 GB").tag(2 * 1_024 * 1_024 * 1_024)
                }
                Button("Apply Limits Now") {
                    repository.enforceRetention()
                }
            }

            Section("Excluded applications") {
                Text("Clipboard changes from these bundle identifiers are never saved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ForEach(settings.excludedBundleIdentifiers.sorted(), id: \.self) { identifier in
                    HStack {
                        Text(identifier)
                            .font(.system(.body, design: .monospaced))
                        Spacer()
                        Button {
                            settings.excludedBundleIdentifiers.remove(identifier)
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(identifier)")
                    }
                }

                HStack {
                    TextField("com.example.application", text: $newBundleIdentifier)
                    Button("Add") {
                        addBundleIdentifier()
                    }
                    .disabled(newBundleIdentifier.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            Section("Privacy") {
                Text("Clipobara stores history only on this Mac. It uses no network, analytics, or cloud sync. Selecting a clip updates the system clipboard; optional auto-paste sends Command-V after you allow keyboard control.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 540, height: 600)
    }

    private func addBundleIdentifier() {
        let identifier = newBundleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else { return }
        settings.excludedBundleIdentifiers.insert(identifier)
        newBundleIdentifier = ""
    }

    private func updateShortcut(_ shortcut: GlobalShortcut) {
        shortcutError = onShortcutChange(shortcut)
    }
}
