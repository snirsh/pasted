import SwiftUI
import AppKit

/// Displays the 5 most recent clipboard items in the menu bar dropdown.
/// Tapping an item pastes it immediately into the active application.
struct RecentItemsMenuSection: View {
    let store: ClipboardStore?
    let pasteService: PasteService?

    @State private var recentItems: [ClipboardItem] = []

    var body: some View {
        Group {
            if recentItems.isEmpty {
                Text("No clipboard history")
                    .foregroundStyle(.secondary)
                    .disabled(true)
            } else {
                ForEach(Array(recentItems.enumerated()), id: \.element.id) { _, item in
                    Button {
                        pasteService?.paste(item)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: iconName(for: item.contentType))
                                .frame(width: 14)
                                .foregroundStyle(accentColor(for: item.contentType))
                            Text(previewText(for: item))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Spacer()
                            Text(relativeTime(from: item.capturedAt))
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            }
        }
        .onAppear { loadItems() }
    }

    // MARK: - Helpers

    private func loadItems() {
        guard let store else { return }
        recentItems = (try? store.fetchRecent(limit: 5)) ?? []
    }

    private func previewText(for item: ClipboardItem) -> String {
        switch item.contentType {
        case .text, .richText:
            let text = item.plainTextContent ?? ""
            return String(text.prefix(40))
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
        case .url:
            if let host = URL(string: item.plainTextContent ?? "")?.host {
                return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
            }
            return item.plainTextContent ?? "Link"
        case .image:
            return "Image"
        case .file:
            let path = item.plainTextContent ?? ""
            return (path as NSString).lastPathComponent.isEmpty ? "File" : (path as NSString).lastPathComponent
        case .color:
            return item.plainTextContent ?? "Color"
        }
    }

    private func iconName(for type: ContentType) -> String {
        switch type {
        case .text:     return "doc.text"
        case .richText: return "doc.richtext"
        case .image:    return "photo"
        case .url:      return "globe"
        case .file:     return "doc"
        case .color:    return "paintpalette"
        }
    }

    private func accentColor(for type: ContentType) -> Color {
        switch type {
        case .text:     return DesignTokens.Colors.textType
        case .richText: return DesignTokens.Colors.richTextType
        case .image:    return DesignTokens.Colors.imageType
        case .url:      return DesignTokens.Colors.urlType
        case .file:     return DesignTokens.Colors.fileType
        case .color:    return DesignTokens.Colors.colorType
        }
    }

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        switch interval {
        case ..<60:     return "\(Int(max(interval, 1)))s"
        case ..<3600:   return "\(Int(interval / 60))m"
        case ..<86400:  return "\(Int(interval / 3600))h"
        default:        return "\(Int(interval / 86400))d"
        }
    }
}
