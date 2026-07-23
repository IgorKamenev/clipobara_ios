import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class ClipboardRepository {
    private(set) var items: [ClipboardItem] = []
    private(set) var lastError: String?

    private let modelContext: ModelContext
    private let fileManager: FileManager
    private let clipsDirectory: URL
    private let settings: AppSettings

    init(
        modelContainer: ModelContainer,
        settings: AppSettings = .shared,
        fileManager: FileManager = .default,
        clipsDirectory customClipsDirectory: URL? = nil
    ) {
        self.modelContext = modelContainer.mainContext
        self.settings = settings
        self.fileManager = fileManager

        if let customClipsDirectory {
            clipsDirectory = customClipsDirectory
        } else {
            let applicationSupport = fileManager.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!
            let storageDirectory = applicationSupport
                .appendingPathComponent("Clipobara", isDirectory: true)
            let legacyStorageDirectory = applicationSupport
                .appendingPathComponent("MyPaste", isDirectory: true)
            if !fileManager.fileExists(atPath: storageDirectory.path),
               fileManager.fileExists(atPath: legacyStorageDirectory.path) {
                try? fileManager.moveItem(at: legacyStorageDirectory, to: storageDirectory)
            }
            clipsDirectory = storageDirectory
                .appendingPathComponent("Clips", isDirectory: true)
        }

        do {
            try fileManager.createDirectory(
                at: clipsDirectory,
                withIntermediateDirectories: true
            )
        } catch {
            lastError = error.localizedDescription
        }
        reload()
    }

    @discardableResult
    func save(_ snapshot: PasteboardSnapshot) -> ClipboardItem? {
        if items.first?.contentHash == snapshot.contentHash {
            items.first?.createdAt = .now
            try? modelContext.save()
            reload()
            return items.first
        }

        let id = UUID()
        let directoryName = id.uuidString
        let itemDirectory = clipsDirectory.appendingPathComponent(
            directoryName,
            isDirectory: true
        )

        do {
            try fileManager.createDirectory(
                at: itemDirectory,
                withIntermediateDirectories: true
            )

            var manifestRepresentations: [ClipboardRepresentation] = []
            for representation in snapshot.representations {
                let filename = "\(representation.itemIndex)-\(UUID().uuidString).payload"
                let destination = itemDirectory.appendingPathComponent(filename)
                try representation.data.write(to: destination, options: .atomic)
                manifestRepresentations.append(
                    ClipboardRepresentation(
                        itemIndex: representation.itemIndex,
                        typeIdentifier: representation.typeIdentifier,
                        filename: filename,
                        byteCount: representation.data.count
                    )
                )
            }

            let manifest = ClipboardManifest(
                representations: manifestRepresentations,
                pasteboardItemCount: snapshot.pasteboardItemCount
            )
            let manifestData = try JSONEncoder().encode(manifest)
            let item = ClipboardItem(
                id: id,
                sourceBundleIdentifier: snapshot.sourceBundleIdentifier,
                sourceApplicationName: snapshot.sourceApplicationName,
                kind: snapshot.kind,
                previewText: snapshot.previewText,
                contentHash: snapshot.contentHash,
                payloadDirectoryName: directoryName,
                totalBytes: snapshot.totalBytes,
                manifestData: manifestData
            )
            modelContext.insert(item)
            try modelContext.save()
            reload()
            enforceRetention()
            return item
        } catch {
            try? fileManager.removeItem(at: itemDirectory)
            lastError = error.localizedDescription
            return nil
        }
    }

    func promoteToFront(_ item: ClipboardItem) {
        item.createdAt = .now
        do {
            try modelContext.save()
            reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func delete(_ item: ClipboardItem) {
        removePayload(for: item)
        modelContext.delete(item)
        do {
            try modelContext.save()
            reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func clearAll() {
        for item in items {
            removePayload(for: item)
            modelContext.delete(item)
        }
        do {
            try modelContext.save()
            reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func payloadData(
        for item: ClipboardItem,
        representation: ClipboardRepresentation
    ) -> Data? {
        let url = clipsDirectory
            .appendingPathComponent(item.payloadDirectoryName, isDirectory: true)
            .appendingPathComponent(representation.filename)
        return try? Data(contentsOf: url, options: .mappedIfSafe)
    }

    func preferredImageData(for item: ClipboardItem) -> Data? {
        guard let manifest = item.manifest else { return nil }
        let preferredTypes = ["public.png", "public.tiff"]
        for type in preferredTypes {
            if let representation = manifest.representations.first(
                where: { $0.typeIdentifier == type }
            ) {
                return payloadData(for: item, representation: representation)
            }
        }
        return nil
    }

    func reload() {
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = max(settings.maximumItemCount * 2, 1_000)
        do {
            items = try modelContext.fetch(descriptor)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func enforceRetention() {
        var runningBytes = 0
        var retainedCount = 0
        var itemsToDelete: [ClipboardItem] = []

        for item in items {
            let fitsCount = retainedCount < settings.maximumItemCount
            let fitsStorage = runningBytes + item.totalBytes <= settings.maximumStorageBytes
            if fitsCount && fitsStorage {
                retainedCount += 1
                runningBytes += item.totalBytes
            } else {
                itemsToDelete.append(item)
            }
        }

        guard !itemsToDelete.isEmpty else { return }
        for item in itemsToDelete {
            removePayload(for: item)
            modelContext.delete(item)
        }
        do {
            try modelContext.save()
            reload()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func removePayload(for item: ClipboardItem) {
        let directory = clipsDirectory.appendingPathComponent(
            item.payloadDirectoryName,
            isDirectory: true
        )
        try? fileManager.removeItem(at: directory)
    }
}
