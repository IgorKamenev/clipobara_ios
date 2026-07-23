import SwiftUI

struct HistoryPanelView: View {
    @Bindable var repository: ClipboardRepository
    @Bindable var model: HistoryPanelModel
    @Bindable var settings: AppSettings
    let onRestore: (ClipboardItem) -> Void
    let onClose: () -> Void

    @FocusState private var searchIsFocused: Bool

    var body: some View {
        VStack(spacing: 10) {
            toolbar
            content
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .preferredColorScheme(.dark)
        .onAppear {
            searchIsFocused = true
        }
        .onChange(of: model.query) {
            model.selectedIndex = 0
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Label("Clipboard History", systemImage: "clipboard")
                .font(.headline)
            Text("\(repository.items.count)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
            Spacer()
            TextField("Search clips", text: $model.query)
                .textFieldStyle(.roundedBorder)
                .frame(width: 260)
                .focused($searchIsFocused)
            Text(settings.historyShortcut.displayName)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("Close (Esc)")
        }
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var content: some View {
        let filteredItems = model.filteredItems(repository.items)
        if filteredItems.isEmpty {
            ContentUnavailableView(
                model.query.isEmpty ? "Clipboard history is empty" : "No matching clips",
                systemImage: model.query.isEmpty ? "clipboard" : "magnifyingglass",
                description: Text(
                    model.query.isEmpty
                        ? "Copy text, images, links, or files to see them here."
                        : "Try another search."
                )
            )
            .frame(maxWidth: .infinity, minHeight: 168)
        } else {
            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 10) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            ClipCardView(
                                item: item,
                                imageData: repository.preferredImageData(for: item),
                                isSelected: index == model.selectedIndex,
                                onSelect: { onRestore(item) },
                                onDelete: { repository.delete(item) }
                            )
                            .id(item.id)
                        }
                    }
                    .padding(4)
                }
                .scrollIndicators(.hidden)
                .onChange(of: model.selectedIndex) {
                    guard filteredItems.indices.contains(model.selectedIndex) else { return }
                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        proxy.scrollTo(filteredItems[model.selectedIndex].id, anchor: .center)
                    }
                }
                .onChange(of: model.presentationSequence) {
                    guard let firstItem = filteredItems.first else { return }
                    var transaction = Transaction()
                    transaction.animation = nil
                    withTransaction(transaction) {
                        proxy.scrollTo(firstItem.id, anchor: .leading)
                    }
                }
            }
            .frame(height: 176)
        }
    }
}
