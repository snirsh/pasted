import SwiftUI

/// Popover/menu for selecting search filters.
/// Organized into sections: Content Type, Source App, and Date Range.
struct FilterPickerView: View {
    @Binding var query: SearchQuery

    /// Available source apps from clipboard history, supplied by the parent.
    var availableSourceApps: [(bundleID: String, name: String)]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Add Filter")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // MARK: - Content Type
                    filterSection("Content Type") {
                        ForEach(ContentType.allCases, id: \.rawValue) { type in
                            filterRow(
                                icon: iconName(for: type),
                                label: type.rawValue.capitalized,
                                isActive: query.contentTypeFilters.contains(type)
                            ) {
                                toggleFilter(.contentType(type))
                            }
                        }
                    }

                    // MARK: - Source App
                    if !availableSourceApps.isEmpty {
                        filterSection("Source App") {
                            ForEach(availableSourceApps, id: \.bundleID) { app in
                                filterRow(
                                    icon: "app.badge",
                                    label: app.name,
                                    isActive: query.sourceAppFilters.contains { $0.bundleID == app.bundleID }
                                ) {
                                    toggleFilter(.sourceApp(bundleID: app.bundleID, name: app.name))
                                }
                            }
                        }
                    }

                    // MARK: - Date Range
                    filterSection("Date") {
                        let datePresets: [(label: String, range: DateRange)] = [
                            ("Today", .today),
                            ("Yesterday", .yesterday),
                            ("Last 7 Days", .lastSevenDays),
                            ("Last 30 Days", .lastThirtyDays)
                        ]

                        ForEach(datePresets, id: \.label) { preset in
                            filterRow(
                                icon: "calendar",
                                label: preset.label,
                                isActive: query.dateRangeFilter == preset.range
                            ) {
                                if query.dateRangeFilter == preset.range {
                                    query = query.removing(.dateRange(preset.range))
                                } else {
                                    query = query.adding(.dateRange(preset.range))
                                }
                            }
                        }
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 220, height: 360)
        .background(.ultraThinMaterial)
    }

    // MARK: - Subviews

    private func filterSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content()
        }
    }

    private func filterRow(icon: String, label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .frame(width: 16)

                Text(label)
                    .font(.system(size: 12))

                Spacer()

                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(isActive ? Color.accentColor.opacity(0.1) : Color.clear)
        )
    }

    // MARK: - Helpers

    private func toggleFilter(_ filter: SearchFilter) {
        if query.filters.contains(filter) {
            query = query.removing(filter)
        } else {
            query = query.adding(filter)
        }
    }

    private func iconName(for contentType: ContentType) -> String {
        switch contentType {
        case .text:     return "doc.text"
        case .richText: return "doc.richtext"
        case .image:    return "photo"
        case .url:      return "link"
        case .file:     return "doc"
        }
    }
}
