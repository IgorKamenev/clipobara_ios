import AppKit
import CryptoKit
import Foundation
import UniformTypeIdentifiers

struct CapturedRepresentation: Sendable {
    let itemIndex: Int
    let typeIdentifier: String
    let data: Data
}

struct PasteboardSnapshot: Sendable {
    static let maximumRepresentationBytes = 64 * 1_024 * 1_024
    static let maximumSnapshotBytes = 128 * 1_024 * 1_024

    let sourceBundleIdentifier: String?
    let sourceApplicationName: String?
    let kind: ClipKind
    let previewText: String?
    let representations: [CapturedRepresentation]
    let pasteboardItemCount: Int
    let contentHash: String

    var totalBytes: Int {
        representations.reduce(0) { $0 + $1.data.count }
    }

    @MainActor
    static func capture(
        from pasteboard: NSPasteboard,
        sourceApplication: NSRunningApplication?
    ) -> PasteboardSnapshot? {
        guard let pasteboardItems = pasteboard.pasteboardItems, !pasteboardItems.isEmpty else {
            return nil
        }

        var representations: [CapturedRepresentation] = []
        var runningSize = 0

        for (itemIndex, item) in pasteboardItems.enumerated() {
            for type in item.types {
                guard let data = item.data(forType: type),
                      !data.isEmpty,
                      data.count <= maximumRepresentationBytes,
                      runningSize + data.count <= maximumSnapshotBytes else {
                    continue
                }
                representations.append(
                    CapturedRepresentation(
                        itemIndex: itemIndex,
                        typeIdentifier: type.rawValue,
                        data: data
                    )
                )
                runningSize += data.count
            }
        }

        guard !representations.isEmpty else { return nil }

        let classification = classify(items: pasteboardItems)
        return PasteboardSnapshot(
            sourceBundleIdentifier: sourceApplication?.bundleIdentifier,
            sourceApplicationName: sourceApplication?.localizedName,
            kind: classification.kind,
            previewText: classification.preview,
            representations: representations,
            pasteboardItemCount: pasteboardItems.count,
            contentHash: hash(representations)
        )
    }

    static func hash(_ representations: [CapturedRepresentation]) -> String {
        var hasher = SHA256()
        for representation in representations.sorted(by: representationSort) {
            hasher.update(data: withUnsafeBytes(of: representation.itemIndex.bigEndian) { Data($0) })
            hasher.update(data: Data(representation.typeIdentifier.utf8))
            hasher.update(data: representation.data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func representationSort(
        _ lhs: CapturedRepresentation,
        _ rhs: CapturedRepresentation
    ) -> Bool {
        if lhs.itemIndex != rhs.itemIndex {
            return lhs.itemIndex < rhs.itemIndex
        }
        return lhs.typeIdentifier < rhs.typeIdentifier
    }

    @MainActor
    private static func classify(items: [NSPasteboardItem]) -> (kind: ClipKind, preview: String?) {
        let types = Set(items.flatMap(\.types))
        let string = items.compactMap { $0.string(forType: .string) }.first
        let trimmedString = string?.trimmingCharacters(in: .whitespacesAndNewlines)

        if types.contains(.fileURL) {
            let names = items.compactMap { item -> String? in
                guard let value = item.string(forType: .fileURL),
                      let url = URL(string: value) else { return nil }
                return url.lastPathComponent
            }
            return (.files, names.isEmpty ? "Files" : names.joined(separator: "\n"))
        }

        if types.contains(.png) || types.contains(.tiff) {
            return (.image, trimmedString)
        }

        if let trimmedString,
           let url = URL(string: trimmedString),
           let scheme = url.scheme,
           ["http", "https"].contains(scheme.lowercased()) {
            return (.link, trimmedString)
        }

        if types.contains(.rtf) || types.contains(.html) {
            return (.richText, trimmedString)
        }

        if let trimmedString {
            return (.text, trimmedString)
        }

        return (.unknown, types.first?.rawValue)
    }
}
