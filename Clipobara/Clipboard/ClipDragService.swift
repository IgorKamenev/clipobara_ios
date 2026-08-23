import Foundation

/// Builds item providers so history clips can be dragged out of the panel and
/// dropped into other applications. Drag & drop is a user-initiated hand-off
/// that the App Sandbox allows without any Accessibility permission, unlike
/// the synthesized Command-V of AutoPasteService.
@MainActor
enum ClipDragService {
    /// Payload data is loaded eagerly because the load handlers run off the
    /// main actor when the drop target requests the data.
    static func itemProvider(
        for item: ClipboardItem,
        repository: ClipboardRepository,
        onDataDelivered: @escaping @Sendable () -> Void
    ) -> NSItemProvider {
        let provider = NSItemProvider()
        guard let manifest = item.manifest else { return provider }

        // A drag carries a single item, so multi-item clips are flattened:
        // the first occurrence of each type wins, preserving fidelity order.
        var registeredTypes = Set<String>()
        for representation in manifest.representations {
            guard registeredTypes.insert(representation.typeIdentifier).inserted,
                  let data = repository.payloadData(for: item, representation: representation)
            else { continue }
            provider.registerDataRepresentation(
                forTypeIdentifier: representation.typeIdentifier,
                visibility: .all
            ) { completion in
                onDataDelivered()
                completion(data, nil)
                return nil
            }
        }
        return provider
    }
}
