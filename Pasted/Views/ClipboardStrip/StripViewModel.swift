import SwiftUI
import SwiftData

/// Shared state between StripPanelController and ClipboardStripView.
/// The controller writes selection/navigation, the view observes and renders.
@MainActor
final class StripViewModel: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var items: [ClipboardItem] = []
    @Published var availableSourceApps: [(bundleID: String, name: String)] = []
    @Published var searchQuery = SearchQuery() {
        didSet {
            guard oldValue != searchQuery, let store else { return }
            reload(from: store)
        }
    }

    /// Incremented each time the strip is shown so SearchBarView can auto-focus.
    @Published var focusTrigger: Int = 0

    private var refreshTimer: Timer?
    private weak var store: ClipboardStore?

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
        self.store = store
        do {
            let newItems: [ClipboardItem]
            if searchQuery.isEmpty {
                newItems = try store.fetchRecent(limit: 200)
            } else {
                newItems = try store.search(searchQuery)
            }
            // Only update if items actually changed to avoid unnecessary SwiftUI redraws
            if newItems.map(\.id) != items.map(\.id) {
                // Remember which item was selected so we can re-find it after reorder
                let selectedID = selectedItem?.id
                items = newItems
                if let id = selectedID,
                   let newIndex = items.firstIndex(where: { $0.id == id }) {
                    selectedIndex = newIndex
                } else if selectedIndex >= items.count {
                    selectedIndex = max(0, items.count - 1)
                }
            }
            availableSourceApps = (try? store.distinctSourceApps()) ?? []
        } catch {
            print("[StripViewModel] Failed to load items: \(error)")
        }
    }

    /// Start polling for new items while the strip is visible.
    func startLiveUpdates() {
        stopLiveUpdates()
        // Use .common mode so the timer fires even during scroll tracking
        let t = Timer(timeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, let store = self.store else { return }
                self.reload(from: store)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        refreshTimer = t
    }

    /// Stop live updates when the strip is dismissed.
    func stopLiveUpdates() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}
