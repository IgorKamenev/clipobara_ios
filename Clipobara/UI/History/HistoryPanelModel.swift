import Foundation
import Observation

@MainActor
@Observable
final class HistoryPanelModel {
    var query = ""
    var selectedIndex = 0
    var presentationSequence = 0
    private(set) var hasCommittedSelection = false

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
        hasCommittedSelection = false
    }

    /// Locks in the clip under the pointer so a double-click cannot restore a
    /// second, different clip after the list reorders under the cursor.
    func commitSelection(at index: Int) -> Bool {
        guard !hasCommittedSelection else { return false }
        selectedIndex = max(index, 0)
        hasCommittedSelection = true
        return true
    }

    func releaseCommit() {
        hasCommittedSelection = false
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
