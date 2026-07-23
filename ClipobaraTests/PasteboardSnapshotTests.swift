import AppKit
import Foundation
import Testing
@testable import Clipobara

struct PasteboardSnapshotTests {
    @Test
    func hashIsStableAcrossRepresentationOrdering() {
        let first = CapturedRepresentation(
            itemIndex: 0,
            typeIdentifier: "public.utf8-plain-text",
            data: Data("hello".utf8)
        )
        let second = CapturedRepresentation(
            itemIndex: 0,
            typeIdentifier: "public.html",
            data: Data("<b>hello</b>".utf8)
        )

        #expect(PasteboardSnapshot.hash([first, second]) == PasteboardSnapshot.hash([second, first]))
    }

    @Test
    func hashIncludesPasteboardItemIndex() {
        let first = CapturedRepresentation(
            itemIndex: 0,
            typeIdentifier: "public.data",
            data: Data([1, 2, 3])
        )
        let second = CapturedRepresentation(
            itemIndex: 1,
            typeIdentifier: "public.data",
            data: Data([1, 2, 3])
        )

        #expect(PasteboardSnapshot.hash([first]) != PasteboardSnapshot.hash([second]))
    }

    @Test @MainActor
    func capturesAndClassifiesTextFromPasteboard() throws {
        let pasteboard = NSPasteboard(name: .init("ClipobaraTests-\(UUID().uuidString)"))
        pasteboard.clearContents()
        #expect(pasteboard.setString("https://example.com", forType: .string))

        let snapshot = try #require(
            PasteboardSnapshot.capture(from: pasteboard, sourceApplication: nil)
        )

        #expect(snapshot.kind == .link)
        #expect(snapshot.previewText == "https://example.com")
        #expect(snapshot.pasteboardItemCount == 1)
        #expect(!snapshot.representations.isEmpty)
    }
}
