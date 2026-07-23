import AppKit
import Foundation

@MainActor
final class PasteboardRestoreService {
    private let pasteboard: NSPasteboard
    private let repository: ClipboardRepository
    private weak var monitor: PasteboardMonitor?

    init(
        pasteboard: NSPasteboard = .general,
        repository: ClipboardRepository,
        monitor: PasteboardMonitor
    ) {
        self.pasteboard = pasteboard
        self.repository = repository
        self.monitor = monitor
    }

    @discardableResult
    func restore(_ item: ClipboardItem) -> Bool {
        guard let manifest = item.manifest, manifest.pasteboardItemCount > 0 else {
            return false
        }

        let pasteboardItems = (0..<manifest.pasteboardItemCount).map { _ in NSPasteboardItem() }
        var representationCount = 0

        for representation in manifest.representations {
            guard pasteboardItems.indices.contains(representation.itemIndex),
                  let data = repository.payloadData(
                    for: item,
                    representation: representation
                  ) else {
                continue
            }
            let type = NSPasteboard.PasteboardType(representation.typeIdentifier)
            if pasteboardItems[representation.itemIndex].setData(data, forType: type) {
                representationCount += 1
            }
        }

        guard representationCount > 0 else { return false }
        pasteboard.clearContents()
        let didWrite = pasteboard.writeObjects(pasteboardItems)
        if didWrite {
            monitor?.ignoreCurrentPasteboardChange()
        }
        return didWrite
    }
}
