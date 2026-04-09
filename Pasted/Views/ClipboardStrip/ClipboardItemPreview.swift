import SwiftUI
import AppKit

/// A clipboard card with three zones:
///   1. Coloured banner  — app brand colour, content type, timestamp, app icon
///   2. Dark content     — text preview / image fill
///   3. Footer bar       — char count / image dimensions + position index
struct ClipboardItemPreview: View {
    let item: ClipboardItem
    var position: Int = 0
    var totalCount: Int = 0

    @AppStorage("previewTextSize") private var previewTextSize: Double = 13.0

    // MARK: - Layout constants
    private let bannerHeight:  CGFloat = 56
    private let footerHeight:  CGFloat = 30
    private let cardWidth:     CGFloat = 200

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            banner
            contentArea
            footer
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Press Return to paste, Shift+Return for plain text")
    }

    // MARK: - Banner

    private var banner: some View {
        ZStack {
            AppBrandColor.color(for: item.sourceAppBundleID)

            HStack(alignment: .center, spacing: 0) {
                // Type + timestamp
                VStack(alignment: .leading, spacing: 2) {
                    Text(contentTypeLabel)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(relativeTime(from: item.capturedAt))
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                .padding(.leading, 10)

                Spacer()

                // App icon
                appIconView
                    .padding(.trailing, 10)
            }
        }
        .frame(height: bannerHeight)
    }

    @ViewBuilder
    private var appIconView: some View {
        if let nsImage = AppIconCache.shared.icon(for: item.sourceAppBundleID) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 40, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 9))
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
        } else {
            // Fallback: first letter of app name on frosted rounded square
            ZStack {
                RoundedRectangle(cornerRadius: 9)
                    .fill(.white.opacity(0.25))
                    .frame(width: 40, height: 40)
                Text(item.sourceAppName?.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Content area

    private var contentArea: some View {
        ZStack {
            Color(red: 0.13, green: 0.13, blue: 0.15)
            contentPreview
                .padding(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var contentPreview: some View {
        if let thumbnailData = item.previewThumbnail,
           let nsImage = NSImage(data: thumbnailData) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            fallbackContent
        }
    }

    @ViewBuilder
    private var fallbackContent: some View {
        switch item.contentType {
        case .text, .richText:
            textContent

        case .url:
            urlContent

        case .image:
            // No thumbnail generated yet — show placeholder
            iconContent(systemName: "photo", tint: .white.opacity(0.35))

        case .file:
            iconContent(systemName: "doc", tint: .white.opacity(0.35))
        }
    }

    private var textContent: some View {
        Text(String((item.plainTextContent ?? "").prefix(400)))
            .font(.system(size: previewTextSize, design: .monospaced))
            .foregroundStyle(.white.opacity(0.9))
            .lineLimit(8)
            .multilineTextAlignment(.leading)
            .truncationMode(.tail)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var urlContent: some View {
        VStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(Color(hex: 0x5AC8FA))
            if let text = item.plainTextContent {
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(5)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func iconContent(systemName: String, tint: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 32))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Text(metadataLabel)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)

            Spacer()

            if position > 0 {
                Text("\(position)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, 10)
        .frame(height: footerHeight)
        .background(Color(red: 0.16, green: 0.16, blue: 0.18))
    }

    // MARK: - Helpers

    private var contentTypeLabel: String {
        switch item.contentType {
        case .text:     return "Text"
        case .richText: return "Rich Text"
        case .image:    return "Image"
        case .url:      return "Link"
        case .file:     return "File"
        }
    }

    private var metadataLabel: String {
        switch item.contentType {
        case .image:
            if let data = item.previewThumbnail ?? (item.contentType == .image ? item.rawData : nil),
               let img = NSImage(data: data) {
                let s = img.size
                return "\(Int(s.width)) × \(Int(s.height))"
            }
            return "Image"
        case .text, .richText, .url:
            if let count = item.plainTextContent?.count {
                return count == 1 ? "1 character" : "\(count.formatted()) characters"
            }
            return ""
        case .file:
            return "File"
        }
    }

    private func relativeTime(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        switch interval {
        case ..<5:      return "just now"
        case ..<60:     return "\(Int(interval))s ago"
        case ..<3600:   return "\(Int(interval / 60))m ago"
        case ..<86400:  return "\(Int(interval / 3600))h ago"
        default:        return "\(Int(interval / 86400))d ago"
        }
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        if position > 0 { parts.append("Item \(position) of \(totalCount)") }
        parts.append(contentTypeLabel)
        if let text = item.plainTextContent { parts.append(String(text.prefix(50))) }
        if let app = item.sourceAppName { parts.append("from \(app)") }
        parts.append(relativeTime(from: item.capturedAt))
        return parts.joined(separator: ", ")
    }
}

// MARK: - Color hex init (local to this file via extension in AppBrandColor.swift)
private extension Color {
    init(hex: UInt32) {
        self.init(
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8)  & 0xFF) / 255,
            blue:  Double( hex        & 0xFF) / 255
        )
    }
}
