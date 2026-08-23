import Foundation
import SwiftData
import Testing
@testable import Clipobara

@MainActor
struct ClipDragServiceTests {
    @Test
    func providesRepresentationsInFidelityOrderAndLoadsData() async throws {
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
        let rich = CapturedRepresentation(
            itemIndex: 0,
            typeIdentifier: "public.rtf",
            data: Data("rich".utf8)
        )
        let plain = CapturedRepresentation(
            itemIndex: 0,
            typeIdentifier: "public.utf8-plain-text",
            data: Data("plain".utf8)
        )
        let secondItemDuplicate = CapturedRepresentation(
            itemIndex: 1,
            typeIdentifier: "public.utf8-plain-text",
            data: Data("second".utf8)
        )
        let representations = [rich, plain, secondItemDuplicate]
        let snapshot = PasteboardSnapshot(
            sourceBundleIdentifier: nil,
            sourceApplicationName: nil,
            kind: .richText,
            previewText: "plain",
            representations: representations,
            pasteboardItemCount: 2,
            contentHash: PasteboardSnapshot.hash(representations)
        )
        let item = try #require(repository.save(snapshot))

        let provider = ClipDragService.itemProvider(
            for: item,
            repository: repository,
            onDataDelivered: {}
        )

        // Duplicate types across pasteboard items collapse to the first one.
        #expect(provider.registeredTypeIdentifiers == [
            "public.rtf",
            "public.utf8-plain-text"
        ])

        let loadedData = await withCheckedContinuation { continuation in
            _ = provider.loadDataRepresentation(
                forTypeIdentifier: "public.utf8-plain-text"
            ) { data, _ in
                continuation.resume(returning: data)
            }
        }
        #expect(loadedData == Data("plain".utf8))
    }
}
