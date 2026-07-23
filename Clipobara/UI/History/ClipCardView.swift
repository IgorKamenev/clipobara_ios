import AppKit
import SwiftUI

struct ClipCardView: View {
    let item: ClipboardItem
    let imageData: Data?
    let isSelected: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 0) {
                header
                content
                footer
            }
            .frame(width: 230, height: 168)
            .background(.black.opacity(0.28))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? Color.accentColor : .white.opacity(0.08),
                        lineWidth: isSelected ? 3 : 1
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy to Clipboard", action: onSelect)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .accessibilityLabel("\(item.kind.title), \(item.previewText ?? "no preview")")
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: item.kind.symbolName)
                .foregroundStyle(.white.opacity(0.9))
            Text(item.kind.title)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(item.createdAt, style: .relative)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.65))
            sourceIcon
        }
        .padding(.horizontal, 10)
        .frame(height: 34)
        .background(headerColor)
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var content: some View {
        if item.kind == .image, let imageData, let image = NSImage(data: imageData) {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
        } else {
            Text(item.previewText?.isEmpty == false ? item.previewText! : "No preview available")
                .font(item.kind == .text ? .system(.body, design: .monospaced) : .body)
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(5)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(10)
        }
    }

    private var footer: some View {
        HStack {
            Text(item.sourceApplicationName ?? "Unknown app")
                .lineLimit(1)
            Spacer()
            Text(item.formattedSize)
        }
        .font(.caption2)
        .foregroundStyle(.white.opacity(0.55))
        .padding(.horizontal, 10)
        .frame(height: 25)
    }

    @ViewBuilder
    private var sourceIcon: some View {
        if let bundleIdentifier = item.sourceBundleIdentifier,
           let applicationURL = NSWorkspace.shared.urlForApplication(
               withBundleIdentifier: bundleIdentifier
           ) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: applicationURL.path))
                .resizable()
                .frame(width: 21, height: 21)
        }
    }

    private var headerColor: Color {
        switch item.kind {
        case .text: Color(red: 0.02, green: 0.25, blue: 0.29)
        case .link: Color(red: 0.18, green: 0.45, blue: 0.92)
        case .image: Color(red: 0.36, green: 0.24, blue: 0.72)
        case .files: Color(red: 0.22, green: 0.47, blue: 0.35)
        case .richText: Color(red: 0.49, green: 0.27, blue: 0.18)
        case .unknown: Color(red: 0.25, green: 0.25, blue: 0.28)
        }
    }
}
