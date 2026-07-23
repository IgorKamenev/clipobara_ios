import AppKit
import Foundation
import SwiftData
import Testing
@testable import Clipobara

@MainActor
struct ClipboardRepositoryTests {
    @Test
    func savesPayloadAndDeduplicatesAdjacentCopies() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ClipboardItem.self,
            configurations: configuration
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = ClipboardRepository(
            modelContainer: container,
            clipsDirectory: directory
        )
        let representation = CapturedRepresentation(
            itemIndex: 0,
            typeIdentifier: "public.utf8-plain-text",
            data: Data("hello".utf8)
        )
        let snapshot = PasteboardSnapshot(
            sourceBundleIdentifier: "com.apple.TextEdit",
            sourceApplicationName: "TextEdit",
            kind: .text,
            previewText: "hello",
            representations: [representation],
            pasteboardItemCount: 1,
            contentHash: PasteboardSnapshot.hash([representation])
        )

        let first = repository.save(snapshot)
        let second = repository.save(snapshot)

        #expect(first != nil)
        #expect(second?.id == first?.id)
        #expect(repository.items.count == 1)
        let storedRepresentation = try #require(repository.items.first?.manifest?.representations.first)
        #expect(repository.payloadData(
            for: try #require(repository.items.first),
            representation: storedRepresentation
        ) == Data("hello".utf8))
    }

    @Test
    func restoresStoredRepresentationsToPasteboard() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ClipboardItem.self,
            configurations: configuration
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = ClipboardRepository(
            modelContainer: container,
            clipsDirectory: directory
        )
        let representation = CapturedRepresentation(
            itemIndex: 0,
            typeIdentifier: NSPasteboard.PasteboardType.string.rawValue,
            data: Data("restored".utf8)
        )
        let snapshot = PasteboardSnapshot(
            sourceBundleIdentifier: nil,
            sourceApplicationName: nil,
            kind: .text,
            previewText: "restored",
            representations: [representation],
            pasteboardItemCount: 1,
            contentHash: PasteboardSnapshot.hash([representation])
        )
        let item = try #require(repository.save(snapshot))
        let pasteboard = NSPasteboard(name: .init("ClipobaraTests-\(UUID().uuidString)"))
        let monitor = PasteboardMonitor(
            pasteboard: pasteboard,
            repository: repository
        )
        let restoreService = PasteboardRestoreService(
            pasteboard: pasteboard,
            repository: repository,
            monitor: monitor
        )

        #expect(restoreService.restore(item))
        #expect(pasteboard.string(forType: .string) == "restored")
    }

    @Test
    func promoteToFrontMovesItemToNewestPosition() throws {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: ClipboardItem.self,
            configurations: configuration
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let repository = ClipboardRepository(
            modelContainer: container,
            clipsDirectory: directory
        )

        func save(_ text: String) -> ClipboardItem? {
            let representation = CapturedRepresentation(
                itemIndex: 0,
                typeIdentifier: "public.utf8-plain-text",
                data: Data(text.utf8)
            )
            return repository.save(
                PasteboardSnapshot(
                    sourceBundleIdentifier: nil,
                    sourceApplicationName: nil,
                    kind: .text,
                    previewText: text,
                    representations: [representation],
                    pasteboardItemCount: 1,
                    contentHash: PasteboardSnapshot.hash([representation])
                )
            )
        }

        let first = try #require(save("first"))
        let second = try #require(save("second"))
        #expect(repository.items.first?.id == second.id)

        repository.promoteToFront(first)
        #expect(repository.items.first?.id == first.id)
        #expect(repository.items.count == 2)
    }
}
