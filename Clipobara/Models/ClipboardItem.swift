import AppKit
import Foundation
import SwiftData
import UniformTypeIdentifiers

enum ClipKind: String, Codable, CaseIterable {
    case text
    case link
    case image
    case files
    case richText
    case unknown

    var title: String {
        switch self {
        case .text: "Text"
        case .link: "Link"
        case .image: "Image"
        case .files: "Files"
        case .richText: "Rich Text"
        case .unknown: "Clipboard"
        }
    }

    var symbolName: String {
        switch self {
        case .text: "text.alignleft"
        case .link: "link"
        case .image: "photo"
        case .files: "doc.on.doc"
        case .richText: "textformat"
        case .unknown: "clipboard"
        }
    }
}

struct ClipboardRepresentation: Codable, Hashable, Sendable {
    let itemIndex: Int
    let typeIdentifier: String
    let filename: String
    let byteCount: Int
}

struct ClipboardManifest: Codable, Sendable {
    let representations: [ClipboardRepresentation]
    let pasteboardItemCount: Int
}

@Model
final class ClipboardItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var sourceBundleIdentifier: String?
    var sourceApplicationName: String?
    var kindRawValue: String
    var previewText: String?
    var contentHash: String
    var payloadDirectoryName: String
    var totalBytes: Int
    @Attribute(.externalStorage) var manifestData: Data

    init(
        id: UUID = UUID(),
        createdAt: Date = .now,
        sourceBundleIdentifier: String?,
        sourceApplicationName: String?,
        kind: ClipKind,
        previewText: String?,
        contentHash: String,
        payloadDirectoryName: String,
        totalBytes: Int,
        manifestData: Data
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceApplicationName = sourceApplicationName
        self.kindRawValue = kind.rawValue
        self.previewText = previewText
        self.contentHash = contentHash
        self.payloadDirectoryName = payloadDirectoryName
        self.totalBytes = totalBytes
        self.manifestData = manifestData
    }

    var kind: ClipKind {
        ClipKind(rawValue: kindRawValue) ?? .unknown
    }

    var manifest: ClipboardManifest? {
        try? JSONDecoder().decode(ClipboardManifest.self, from: manifestData)
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }
}
