import SwiftUI
import SwiftData

/// Shared state between StripPanelController and ClipboardStripView.
/// The controller writes selection/navigation, the view observes and renders.
@MainActor
final class StripViewModel: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var items: [ClipboardItem] = []

    var selectedItem: ClipboardItem? {
        guard selectedIndex >= 0, selectedIndex < items.count else { return nil }
        return items[selectedIndex]
    }

    func moveLeft() {
        guard selectedIndex > 0 else { return }
        selectedIndex -= 1
    }

    func moveRight() {
        guard selectedIndex < items.count - 1 else { return }
        selectedIndex += 1
    }

    func selectFirst() {
        guard !items.isEmpty else { return }
        selectedIndex = 0
    }

    func selectLast() {
        guard !items.isEmpty else { return }
        selectedIndex = items.count - 1
    }

    func select(at index: Int) {
        guard index >= 0, index < items.count else { return }
        selectedIndex = index
    }

    func reload(from store: ClipboardStore) {
        do {
            items = try store.fetchRecent(limit: 200)
            if selectedIndex >= items.count {
                selectedIndex = max(0, items.count - 1)
            }
        } catch {
            print("[StripViewModel] Failed to load items: \(error)")
        }
    }
}
