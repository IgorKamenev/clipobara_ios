import Foundation
import Testing
@testable import Clipobara



struct ClipboardModelTests {
    @Test
    func manifestRoundTripsThroughModel() throws {
        let manifest = ClipboardManifest(
            representations: [
                ClipboardRepresentation(
                    itemIndex: 0,
                    typeIdentifier: "public.utf8-plain-text",
                    filename: "0.payload",
                    byteCount: 5
                )
            ],
            pasteboardItemCount: 1
        )
        let item = ClipboardItem(
            sourceBundleIdentifier: "com.apple.TextEdit",
            sourceApplicationName: "TextEdit",
            kind: .text,
            previewText: "hello",
            contentHash: "hash",
            payloadDirectoryName: UUID().uuidString,
            totalBytes: 5,
            manifestData: try JSONEncoder().encode(manifest)
        )

        #expect(item.kind == .text)
        #expect(item.manifest?.representations == manifest.representations)
        #expect(item.manifest?.pasteboardItemCount == 1)
    }

    @Test @MainActor
    func historySelectionStaysWithinBounds() {
        let model = HistoryPanelModel()
        let items = (0..<2).map { index in
            ClipboardItem(
                sourceBundleIdentifier: nil,
                sourceApplicationName: nil,
                kind: .text,
                previewText: "Item \(index)",
                contentHash: "\(index)",
                payloadDirectoryName: "\(index)",
                totalBytes: 1,
                manifestData: Data()
            )
        }

        model.moveSelection(by: 10, in: items)
        #expect(model.selectedIndex == 1)
        model.moveSelection(by: -10, in: items)
        #expect(model.selectedIndex == 0)

        let previousPresentation = model.presentationSequence
        model.reset()
        #expect(model.presentationSequence == previousPresentation + 1)
    }

    @Test @MainActor
    func commitSelectionIgnoresASecondActivation() {
        let model = HistoryPanelModel()

        #expect(model.commitSelection(at: 2))
        #expect(model.selectedIndex == 2)
        #expect(model.hasCommittedSelection)

        #expect(!model.commitSelection(at: 0))
        #expect(model.selectedIndex == 2)

        model.releaseCommit()
        #expect(!model.hasCommittedSelection)
        #expect(model.commitSelection(at: 0))
        #expect(model.selectedIndex == 0)

        model.reset()
        #expect(!model.hasCommittedSelection)
        #expect(model.selectedIndex == 0)
        #expect(model.commitSelection(at: 1))
        #expect(model.selectedIndex == 1)
    }

    @Test
    func defaultShortcutHasReadableName() {
        #expect(GlobalShortcut.default.displayName.contains("V"))
        #expect(!GlobalShortcut.default.displayName.isEmpty)
    }

    @Test @MainActor
    func selectionSettingsDefaultAsSpecified() {
        let suiteName = "ClipobaraTests.AppSettings.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let settings = AppSettings(defaults: defaults)
        #expect(settings.moveSelectedClipToFront)
        // Auto-paste is disabled for now; restore with the AppSettings property.
        // #expect(!settings.autoPasteOnSelect)
    }
}
