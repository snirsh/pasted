import SwiftUI

/// Appearance preferences: text size and card width with a live preview.
struct AppearancePreferencesView: View {
    @AppStorage("previewTextSize") private var previewTextSize: Double = 13.0
    @AppStorage("cardSizeScale") private var cardSizeScale: Double = 1.0

    var body: some View {
        Form {
            Section("Text Size") {
                Picker("Text size", selection: $previewTextSize) {
                    Text("Small").tag(11.0)
                    Text("Medium").tag(13.0)
                    Text("Large").tag(16.0)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text("Controls the size of text shown inside clipboard preview cards")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Card Width") {
                Picker("Card width", selection: $cardSizeScale) {
                    Text("Narrow").tag(0.8)
                    Text("Normal").tag(1.0)
                    Text("Wide").tag(1.25)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Text("Controls how wide each card appears in the clipboard strip")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Live Preview") {
                previewSection
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 520)
    }

    // MARK: - Live Card Preview

    private var previewSection: some View {
        HStack {
            Spacer()
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(width: cardWidth + 64, height: 264)

                mockCard
                    .animation(.easeInOut(duration: 0.2), value: cardSizeScale)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var cardWidth: Double { 200.0 * cardSizeScale }

    private var mockCard: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Color.white.opacity(0.08)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("let greeting = \"Hello!\"\nprint(greeting)\n\n// Clipboard preview\n// appears here")
                            .font(.system(size: previewTextSize, design: .monospaced))
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(10)
                            .multilineTextAlignment(.leading)
                    }
                    .padding(8)
                }
                .frame(width: cardWidth - 16, height: 170)
                .clipped()
                .cornerRadius(6)

                Image(systemName: "doc.text")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(5)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }

            VStack(spacing: 2) {
                Text("Finder")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text("just now")
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
                .shadow(color: .black.opacity(0.15), radius: 3, x: 0, y: 1)
        )
        .frame(width: cardWidth, height: 240)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor, lineWidth: 2.5)
        )
    }
}
