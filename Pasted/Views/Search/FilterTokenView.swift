import SwiftUI

/// Displays a single active search filter as a chip/tag with a remove button.
/// Shows the filter's icon, label, and an X button to dismiss.
struct FilterTokenView: View {
    let filter: SearchFilter
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: filter.iconName)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)

            Text(filter.displayLabel)
                .font(.system(size: 11, weight: .medium))
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(filter.displayLabel) filter")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.accentColor.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(Color.accentColor.opacity(0.3), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(filter.displayLabel) filter")
        .accessibilityHint("Activate to remove this filter")
    }
}
