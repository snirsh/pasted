import SwiftUI
import AppKit

/// Routes to the appropriate content renderer based on `item.contentType`.
struct DetailContentView: View {
    let item: ClipboardItem

    var body: some View {
        Group {
            switch item.contentType {
            case .text, .richText:
                textDetail
            case .image:
                imageDetail
            case .url:
                urlDetail
            case .file:
                fileDetail
            case .color:
                colorDetail
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Text

    private var textDetail: some View {
        let text = item.plainTextContent ?? ""
        let isCode = CodeDetector.isCode(text)
        return ScrollView {
            Text(text)
                .font(isCode ? DesignTokens.Typography.detailMono : .system(size: 13))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .padding(16)
        }
    }

    // MARK: - Image

    @ViewBuilder
    private var imageDetail: some View {
        let imageData = item.previewThumbnail ?? item.rawData
        if let nsImage = NSImage(data: imageData) {
            ZStack {
                if item.hasAlpha {
                    CheckerboardView()
                }
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(12)
            }
        } else {
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - URL

    private var urlDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if let url = URL(string: item.plainTextContent ?? "") {
                    let domain = url.host.map {
                        $0.hasPrefix("www.") ? String($0.dropFirst(4)) : $0
                    } ?? ""
                    Text(domain)
                        .font(DesignTokens.Typography.detailTitle)
                        .foregroundStyle(DesignTokens.Colors.urlType)
                }
                Text(item.plainTextContent ?? "")
                    .font(DesignTokens.Typography.cardMono)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(16)
        }
    }

    // MARK: - File

    private var fileDetail: some View {
        VStack(spacing: 12) {
            let path = item.plainTextContent ?? ""
            let filename = (path as NSString).lastPathComponent
            let icon = NSWorkspace.shared.icon(forFile: path)

            Image(nsImage: icon)
                .resizable()
                .frame(width: 64, height: 64)

            Text(filename)
                .font(DesignTokens.Typography.detailTitle)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text(path)
                .font(DesignTokens.Typography.metadata)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .multilineTextAlignment(.center)
        }
        .padding(16)
    }

    // MARK: - Color

    private var colorDetail: some View {
        VStack(spacing: 16) {
            if let hex = item.plainTextContent, let color = Color(hexString: hex) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(color)
                    .frame(width: 160, height: 100)
                    .shadow(color: color.opacity(0.4), radius: 12, x: 0, y: 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.white.opacity(0.15), lineWidth: 1)
                    )

                Text(hex)
                    .font(DesignTokens.Typography.detailMono)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)

                rgbRow(hex: hex)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func rgbRow(hex: String) -> some View {
        if let value = UInt32(hex.dropFirst(), radix: 16) {
            let r = Int((value >> 16) & 0xFF)
            let g = Int((value >> 8)  & 0xFF)
            let b = Int( value        & 0xFF)
            HStack(spacing: 16) {
                rgbChip("R", value: r, color: .red)
                rgbChip("G", value: g, color: .green)
                rgbChip("B", value: b, color: .blue)
            }
        }
    }

    private func rgbChip(_ label: String, value: Int, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(DesignTokens.Typography.timestamp)
                .foregroundStyle(color.opacity(0.8))
            Text("\(value)")
                .font(DesignTokens.Typography.cardBadgeMed)
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
