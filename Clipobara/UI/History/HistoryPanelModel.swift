import Foundation
import Observation

@MainActor
@Observable
final class HistoryPanelModel {
    var query = ""
    var selectedIndex = 0
    var presentationSequence = 0

    func filteredItems(_ items: [ClipboardItem]) -> [ClipboardItem] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return items }
        return items.filter { item in
            item.previewText?.localizedCaseInsensitiveContains(trimmedQuery) == true
                || item.sourceApplicationName?.localizedCaseInsensitiveContains(trimmedQuery) == true
                || item.kind.title.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    func reset() {
        query = ""
        selectedIndex = 0
        presentationSequence &+= 1
    }

    func moveSelection(by offset: Int, in items: [ClipboardItem]) {
        let filtered = filteredItems(items)
        guard !filtered.isEmpty else {
            selectedIndex = 0
            return
        }
        selectedIndex = min(max(selectedIndex + offset, 0), filtered.count - 1)
    }

    func selectedItem(in items: [ClipboardItem]) -> ClipboardItem? {
        let filtered = filteredItems(items)
        guard filtered.indices.contains(selectedIndex) else { return filtered.first }
        return filtered[selectedIndex]
    }
}
