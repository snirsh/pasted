import SwiftUI
import SwiftData

/// The main horizontal clipboard strip displaying recent clipboard items.
/// Activated via the global keyboard shortcut, appearing as a floating strip.
struct ClipboardStripView: View {
    @Query(sort: \ClipboardItem.capturedAt, order: .reverse)
    private var items: [ClipboardItem]

    @Environment(\.modelContext) private var modelContext

    @State private var selectedIndex: Int?

    @StateObject private var navigationHandler = StripNavigationHandler()

    var onPaste: (ClipboardItem) -> Void
    var onDismiss: () -> Void

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemPreview(item: item)
                            .frame(width: 120, height: 140)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(selectedIndex == index
                                          ? Color.accentColor.opacity(0.15)
                                          : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(selectedIndex == index
                                            ? Color.accentColor
                                            : Color.clear, lineWidth: 2)
                            )
                            .id(index)
                            .onTapGesture {
                                selectItem(at: index)
                            }
                            .onTapGesture(count: 2) {
                                selectItem(at: index)
                                pasteSelected()
                            }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: selectedIndex) { _, newIndex in
                if let newIndex {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }
            .onChange(of: navigationHandler.selectedIndex) { _, newIndex in
                selectedIndex = newIndex
            }
        }
        .frame(height: 156)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            navigationHandler.itemCount = items.count
            if !items.isEmpty {
                selectedIndex = 0
                navigationHandler.selectedIndex = 0
            }
        }
        .onChange(of: items.count) { _, newCount in
            navigationHandler.itemCount = newCount
        }
    }

    // MARK: - Navigation

    func selectNext() {
        navigationHandler.moveRight()
        selectedIndex = navigationHandler.selectedIndex
    }

    func selectPrevious() {
        navigationHandler.moveLeft()
        selectedIndex = navigationHandler.selectedIndex
    }

    func selectItem(at index: Int) {
        guard index >= 0, index < items.count else { return }
        selectedIndex = index
        navigationHandler.selectedIndex = index
    }

    func pasteSelected() {
        guard let index = selectedIndex, index < items.count else { return }
        onPaste(items[index])
    }
}
