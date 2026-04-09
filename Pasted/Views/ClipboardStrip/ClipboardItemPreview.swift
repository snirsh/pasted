import SwiftUI
import AppKit

/// A clipboard card with three zones:
///   1. Coloured banner  — app brand colour, content type, timestamp, app icon
///   2. Dark content     — text preview / image fill / specialised type view
///   3. Footer bar       — char count / image dimensions + position index
struct ClipboardItemPreview: View {
    let item: ClipboardItem
    var position: Int = 0
    var totalCount: Int = 0
    /// Active search text for highlighting; empty string = no highlight.
    var searchText: String = ""

    @AppStorage("previewTextSize") private var previewTextSize: Double = 13.0

    var body: some View {
        VStack(spacing: 0) {
            banner
            contentArea
            footer
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Layout.cardCornerRadius))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Press Return to paste, Shift+Return for plain text")
    }

    // MARK: - Banner

    private var banner: some View {
        ZStack {
            AppBrandColor.color(for: item.sourceAppBundleID)

            HStack(alignment: .center, spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(contentTypeLabel)
                        .font(DesignTokens.Typography.bannerTitle)
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(relativeTime(from: item.capturedAt))
                        .font(DesignTokens.Typography.bannerSub)
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
                .padding(.leading, DesignTokens.Layout.cardPadding)

                Spacer()

                appIconView
                    .padding(.trailing, DesignTokens.Layout.cardPadding)
            }
        }
        .frame(height: DesignTokens.Layout.bannerHeight)
    }

    @ViewBuilder
    private var appIconView: some View {
        if let nsImage = AppIconCache.shared.icon(for: item.sourceAppBundleID) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .frame(width: DesignTokens.Layout.appIconSize, height: DesignTokens.Layout.appIconSize)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Layout.appIconCornerRadius))
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Layout.appIconCornerRadius)
                    .fill(.white.opacity(0.25))
                    .frame(width: DesignTokens.Layout.appIconSize, height: DesignTokens.Layout.appIconSize)
                Text(item.sourceAppName?.prefix(1).uppercased() ?? "?")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Content area

    private var contentArea: some View {
        ZStack {
            DesignTokens.Colors.cardContentBg
            contentPreview
                .padding(DesignTokens.Layout.cardPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var contentPreview: some View {
        switch item.contentType {
        case .color:
            colorContent
        case .url:
            LinkCardContent(urlString: item.plainTextContent ?? "")
        case .image:
            imageContent
        case .text, .richText:
            textContent
        case .file:
            iconContent(systemName: "doc", tint: .white.opacity(0.35))
        }
    }

    // MARK: - Text content (with code detection + search highlight)

    private var textContent: some View {
        let raw = String((item.plainTextContent ?? "").prefix(400))
        let isCode = CodeDetector.isCode(raw)
        let font: Font = isCode
            ? .system(size: previewTextSize, design: .monospaced)
            : .system(size: previewTextSize)

        return Group {
            if searchText.isEmpty {
                Text(raw)
                    .font(font)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(8)
                    .multilineTextAlignment(.leading)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Text(TextHighlighter.highlight(raw, query: searchText, highlightColor: DesignTokens.Colors.searchHighlight))
                    .font(font)
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(8)
                    .multilineTextAlignment(.leading)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    // MARK: - Image content (with checkerboard for transparency)

    @ViewBuilder
    private var imageContent: some View {
        if let thumbnailData = item.previewThumbnail,
           let nsImage = NSImage(data: thumbnailData) {
            ZStack {
                if item.hasAlpha {
                    CheckerboardView()
                }
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            }
        } else {
            iconContent(systemName: "photo", tint: .white.opacity(0.35))
        }
    }

    // MARK: - Color content (swatch + hex)

    private var colorContent: some View {
        VStack(spacing: 6) {
            if let hex = item.plainTextContent, let color = Color(hexString: hex) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                    )
                Text(hex)
                    .font(DesignTokens.Typography.metadataMono)
                    .foregroundStyle(.white.opacity(0.8))
            } else {
                iconContent(systemName: "paintpalette", tint: DesignTokens.Colors.colorType)
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
                .font(DesignTokens.Typography.metadata)
                .foregroundStyle(.white.opacity(0.45))
                .lineLimit(1)

            Spacer()

            if position > 0 {
                Text("\(position)")
                    .font(DesignTokens.Typography.cardBadgeMed)
                    .foregroundStyle(.white.opacity(0.45))
            }
        }
        .padding(.horizontal, DesignTokens.Layout.cardPadding)
        .frame(height: DesignTokens.Layout.footerHeight)
        .background(DesignTokens.Colors.cardFooterBg)
    }

    // MARK: - Helpers

    private var contentTypeLabel: String {
        switch item.contentType {
        case .text:     return "Text"
        case .richText: return "Rich Text"
        case .image:    return "Image"
        case .url:      return "Link"
        case .file:     return "File"
        case .color:    return "Color"
        }
    }

    private var metadataLabel: String {
        switch item.contentType {
        case .color:
            return item.plainTextContent ?? "Color"
        case .image:
            let imageData = item.previewThumbnail ?? item.rawData
            if let img = NSImage(data: imageData) {
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
