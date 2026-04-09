import SwiftUI

/// A single preview card for a clipboard item, showing a visual thumbnail,
/// content type badge, source app name, and relative timestamp.
struct ClipboardItemPreview: View {
    let item: ClipboardItem
    var position: Int = 0
    var totalCount: Int = 0

    @AppStorage("previewTextSize") private var previewTextSize: Double = 13.0

    var body: some View {
        VStack(spacing: 4) {
            // Preview area
            ZStack(alignment: .topTrailing) {
                previewContent
                    .frame(maxWidth: .infinity, minHeight: 170, maxHeight: 170)
                    .clipped()
                    .cornerRadius(6)

                // Content type badge
                Image(systemName: iconName(for: item.contentType))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
            .frame(maxWidth: .infinity, minHeight: 170, maxHeight: 170)

            // Metadata area: ~40pt
            VStack(spacing: 2) {
                Text(item.sourceAppName ?? "Unknown")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Text(relativeTime(from: item.capturedAt))
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Press Return to paste, Shift Return for plain text")
    }

    // MARK: - Preview Content

    @ViewBuilder
    private var previewContent: some View {
        if let thumbnailData = item.previewThumbnail,
           let nsImage = NSImage(data: thumbnailData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            fallbackPreview
        }
    }

    @ViewBuilder
    private var fallbackPreview: some View {
        switch item.contentType {
        case .text:
            textFallback
        case .richText:
            textFallback
        case .url:
            urlFallback
        default:
            iconFallback
        }
    }

    private var textFallback: some View {
        ZStack {
            Color.white.opacity(0.08)
            VStack(alignment: .leading, spacing: 2) {
                if let text = item.plainTextContent {
                    Text(String(text.prefix(500)))
                        .font(.system(size: previewTextSize, design: .monospaced))
                        .foregroundColor(.white.opacity(0.85))
                        .lineLimit(12)
                        .multilineTextAlignment(.leading)
                } else {
                    Image(systemName: iconName(for: item.contentType))
                        .font(.title2)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(8)
        }
    }

    private var urlFallback: some View {
        ZStack {
            Color.white.opacity(0.08)
            VStack(spacing: 6) {
                Image(systemName: "link")
                    .font(.title2)
                    .foregroundStyle(.blue)
                if let text = item.plainTextContent {
                    Text(text)
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(4)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(8)
        }
    }

    private var iconFallback: some View {
        ZStack {
            Color.white.opacity(0.08)
            Image(systemName: iconName(for: item.contentType))
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.4))
        }
    }

    // MARK: - Helpers

    private func iconName(for contentType: ContentType) -> String {
        switch contentType {
        case .text:      return "doc.text"
        case .richText:  return "doc.richtext"
        case .image:     return "photo"
        case .url:       return "link"
        case .file:      return "doc"
        }
    }

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        switch interval {
        case ..<60:
            return "just now"
        case ..<3600:
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        case ..<86400:
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        default:
            let days = Int(interval / 86400)
            return "\(days)d ago"
        }
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        if position > 0 && totalCount > 0 {
            parts.append("Item \(position) of \(totalCount)")
        }
        parts.append(item.contentType.rawValue)
        if let text = item.plainTextContent {
            let snippet = String(text.prefix(50))
            parts.append(snippet)
        }
        if let app = item.sourceAppName {
            parts.append("from \(app)")
        }
        parts.append(relativeTime(from: item.capturedAt))
        return parts.joined(separator: ", ")
    }
}
