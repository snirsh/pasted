import SwiftUI

/// Search bar with text input, active filter tokens, and a filter picker button.
/// Designed for the clipboard strip's search functionality.
struct SearchBarView: View {
    @Binding var query: SearchQuery

    /// Available source apps for the filter picker, supplied by the parent.
    var availableSourceApps: [(bundleID: String, name: String)] = []

    /// Incrementing this value auto-focuses the search field (used when the strip opens).
    var focusTrigger: Int = 0

    @State private var showFilterPicker = false
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            // Active filter tokens
            if !query.filters.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(query.filters) { filter in
                            FilterTokenView(filter: filter) {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    query = query.removing(filter)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: 200)
            }

            // Search text field
            TextField("Search clipboard history...", text: $query.text)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .focused($isSearchFieldFocused)
                .accessibilityLabel("Search clipboard history")

            // Filter button
            Button {
                showFilterPicker.toggle()
            } label: {
                Image(systemName: query.filters.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(query.filters.isEmpty ? .secondary : .accentColor)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Filter options")
            .popover(isPresented: $showFilterPicker, arrowEdge: .bottom) {
                FilterPickerView(
                    query: $query,
                    availableSourceApps: availableSourceApps
                )
            }

            // Clear button (visible when query is not empty)
            if !query.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        query = SearchQuery()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSearchFieldFocused ? Color.accentColor.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onChange(of: focusTrigger) { _, _ in
            // Auto-focus when the strip opens; small delay ensures the panel is key first
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFieldFocused = true
            }
        }
    }
}
