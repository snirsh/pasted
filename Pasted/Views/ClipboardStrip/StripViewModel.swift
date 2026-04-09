import SwiftUI
import SwiftData

/// Tab selection for the clipboard strip.
enum StripTab: Equatable {
    case history
    case pinboard(Pinboard)

    static func == (lhs: StripTab, rhs: StripTab) -> Bool {
        switch (lhs, rhs) {
        case (.history, .history): return true
        case (.pinboard(let a), .pinboard(let b)): return a.id == b.id
        default: return false
        }
    }
}

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

    /// Whether the detail preview modal is open.
    @Published var isShowingPreview: Bool = false

    /// The active plain-text search string (for highlight passing to cards).
    var searchText: String { searchQuery.text }

    // MARK: - Pinboard state

    @Published var pinboards: [Pinboard] = []
    @Published var activeTab: StripTab = .history

    private var refreshTimer: Timer?
    private weak var store: ClipboardStore?
    private var modelContext: ModelContext?

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
            switch activeTab {
            case .history:
                if searchQuery.isEmpty {
                    newItems = try store.fetchRecent(limit: 200)
                } else {
                    newItems = try store.search(searchQuery)
                }
            case .pinboard(let board):
                // Sorted by displayOrder ascending
                newItems = board.entries
                    .sorted { $0.displayOrder < $1.displayOrder }
                    .compactMap { $0.item }
            }

            if newItems.map(\.id) != items.map(\.id) {
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

    // MARK: - Pinboard operations

    func loadPinboards(context: ModelContext) {
        self.modelContext = context
        let descriptor = FetchDescriptor<Pinboard>(
            sortBy: [SortDescriptor(\.displayOrder), SortDescriptor(\.createdAt)]
        )
        pinboards = (try? context.fetch(descriptor)) ?? []
    }

    func createPinboard(name: String) {
        guard let context = modelContext else { return }
        let order = pinboards.count
        let board = Pinboard(name: name, displayOrder: order)
        context.insert(board)
        try? context.save()
        pinboards.append(board)
    }

    func renamePinboard(_ board: Pinboard, to name: String) {
        board.name = name
        try? modelContext?.save()
        objectWillChange.send()
    }

    func deletePinboard(_ board: Pinboard) {
        modelContext?.delete(board)
        try? modelContext?.save()
        if case .pinboard(let active) = activeTab, active.id == board.id {
            activeTab = .history
        }
        pinboards.removeAll { $0.id == board.id }
        if let store { reload(from: store) }
    }

    func addItem(_ item: ClipboardItem, to board: Pinboard) {
        guard let context = modelContext else { return }
        let order = board.entries.count
        let entry = PinboardEntry(item: item, pinboard: board, displayOrder: order)
        context.insert(entry)
        try? context.save()
    }

    func removeEntry(_ entry: PinboardEntry) {
        modelContext?.delete(entry)
        try? modelContext?.save()
        if let store { reload(from: store) }
    }

    func reorderEntry(_ entry: PinboardEntry, to newOrder: Int, in board: Pinboard) {
        let sorted = board.entries.sorted { $0.displayOrder < $1.displayOrder }
        var entries = sorted.filter { $0.id != entry.id }
        entries.insert(entry, at: min(newOrder, entries.count))
        for (i, e) in entries.enumerated() { e.displayOrder = i }
        try? modelContext?.save()
        if let store { reload(from: store) }
    }

    func switchTab(_ tab: StripTab) {
        activeTab = tab
        selectedIndex = 0
        isShowingPreview = false
        if let store { reload(from: store) }
    }

    /// Start polling for new items while the strip is visible.
    func startLiveUpdates() {
        stopLiveUpdates()
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
