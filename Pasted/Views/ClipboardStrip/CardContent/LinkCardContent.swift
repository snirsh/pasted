import SwiftUI

/// Renders a URL clipboard item with the domain name prominent and the full URL secondary.
/// Replaces the JPEG thumbnail approach for URL items.
struct LinkCardContent: View {
    let urlString: String

    private var url: URL? { URL(string: urlString) }

    private var displayDomain: String {
        guard let host = url?.host else { return urlString }
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.urlType)

            Text(displayDomain)
                .font(DesignTokens.Typography.bannerTitle)
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.middle)

            Text(urlString)
                .font(DesignTokens.Typography.timestamp)
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.middle)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
