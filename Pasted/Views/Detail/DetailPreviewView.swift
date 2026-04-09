import SwiftUI
import AppKit

/// Full-detail overlay shown when the user presses Space on a selected clipboard item.
/// Displays type-specific metadata and content in a larger view without pasting.
struct DetailPreviewView: View {
    let item: ClipboardItem
    var onClose: () -> Void
    var onPaste: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.3)
            DetailContentView(item: item)
            Divider().opacity(0.3)
            footer
        }
        .frame(
            width: DesignTokens.Layout.previewModalWidth,
            height: DesignTokens.Layout.previewModalHeight
        )
        .background(.ultraThickMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Layout.panelCornerRadius))
        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: 8)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            // App icon
            if let nsImage = AppIconCache.shared.icon(for: item.sourceAppBundleID) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Text(item.sourceAppName ?? "Unknown")
                .font(DesignTokens.Typography.cardBadgeMed)
                .foregroundStyle(.secondary)

            Spacer()

            Button("Paste") { onPaste() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

            Button {
                onClose()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.tertiary)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Image(systemName: typeIcon)
                .font(DesignTokens.Typography.metadata)
                .foregroundStyle(.secondary)
            Text(metadataString)
                .font(DesignTokens.Typography.metadata)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Text(relativeTime(from: item.capturedAt))
                .font(DesignTokens.Typography.timestamp)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private var typeIcon: String {
        switch item.contentType {
        case .text:     return "doc.text"
        case .richText: return "doc.richtext"
        case .image:    return "photo"
        case .url:      return "link"
        case .file:     return "doc"
        case .color:    return "paintpalette"
        }
    }

    private var metadataString: String {
        switch item.contentType {
        case .text, .richText:
            let text = item.plainTextContent ?? ""
            let chars = text.count
            let words = text.components(separatedBy: .whitespacesAndNewlines)
                            .filter { !$0.isEmpty }.count
            return "\(chars.formatted()) characters · \(words.formatted()) words"
        case .url:
            return item.plainTextContent ?? ""
        case .image:
            let imageData = item.previewThumbnail ?? item.rawData
            if let img = NSImage(data: imageData) {
                return "\(Int(img.size.width)) × \(Int(img.size.height)) px"
            }
            return "Image"
        case .file:
            if let path = item.plainTextContent {
                return (path as NSString).lastPathComponent
            }
            return "File"
        case .color:
            return item.plainTextContent ?? "Color"
        }
    }

    private func relativeTime(from date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
