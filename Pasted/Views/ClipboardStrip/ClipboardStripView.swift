import SwiftUI
import SwiftData

/// The main horizontal clipboard strip displaying recent clipboard items.
struct ClipboardStripView: View {
    @ObservedObject var viewModel: StripViewModel

    var onPaste: (ClipboardItem) -> Void
    var onDismiss: () -> Void

    @AppStorage("cardSizeScale") private var cardSizeScale: Double = 1.0

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Pinboard tab bar (shown when there are pinboards or always for consistency)
                PinboardTabBar(viewModel: viewModel)
                    .background(.ultraThinMaterial.opacity(0.5))

                Divider().opacity(0.3)

                SearchBarView(
                    query: $viewModel.searchQuery,
                    availableSourceApps: viewModel.availableSourceApps,
                    focusTrigger: viewModel.focusTrigger
                )
                .padding(.horizontal, 12)
                .padding(.top, 6)
                .padding(.bottom, 4)

                Divider()
                    .opacity(0.4)

                Group {
                    if viewModel.items.isEmpty {
                        emptyState
                    } else {
                        stripContent
                    }
                }
                .frame(height: 220)
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Layout.stripCornerRadius))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Clipboard History, \(viewModel.items.count) items")

            // Detail preview modal overlay
            if viewModel.isShowingPreview, let item = viewModel.selectedItem {
                DetailPreviewView(item: item) {
                    viewModel.isShowingPreview = false
                } onPaste: {
                    onPaste(item)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(DesignTokens.Animation.previewShow, value: viewModel.isShowingPreview)
    }

    // MARK: - Strip Content

    private var stripContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: DesignTokens.Layout.cardSpacing) {
                    ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemPreview(
                            item: item,
                            position: index + 1,
                            totalCount: viewModel.items.count,
                            searchText: viewModel.searchText
                        )
                        .frame(
                            width: DesignTokens.Layout.cardBaseWidth * cardSizeScale,
                            height: DesignTokens.Layout.cardBaseHeight
                        )
                        .background(
                            RoundedRectangle(cornerRadius: DesignTokens.Layout.cardCornerRadius)
                                .fill(viewModel.selectedIndex == index
                                      ? DesignTokens.Colors.selectionFill
                                      : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: DesignTokens.Layout.cardCornerRadius)
                                .strokeBorder(
                                    viewModel.selectedIndex == index
                                        ? DesignTokens.Colors.selectionBorder
                                        : Color.clear,
                                    lineWidth: DesignTokens.Layout.selectionBorderWidth
                                )
                        )
                        .id(index)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            viewModel.select(at: index)
                            onPaste(item)
                        }
                        .onTapGesture {
                            viewModel.select(at: index)
                        }
                        .contextMenu {
                            itemContextMenu(item: item)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                withAnimation(DesignTokens.Animation.navScroll) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func itemContextMenu(item: ClipboardItem) -> some View {
        Button("Paste") { onPaste(item) }
        Button("Paste as Plain Text") {
            // Signal to controller via a notification — keeps view passive
            NotificationCenter.default.post(
                name: .pasteAsPlainText,
                object: item
            )
        }

        Divider()

        // Add to pinboard submenu
        if viewModel.pinboards.isEmpty {
            Menu("Add to Pinboard") {
                Button("New Pinboard…") { promptNewPinboard(for: item) }
            }
        } else {
            Menu("Add to Pinboard") {
                ForEach(viewModel.pinboards) { board in
                    Button(board.name) { viewModel.addItem(item, to: board) }
                }
                Divider()
                Button("New Pinboard…") { promptNewPinboard(for: item) }
            }
        }

        // Remove from pinboard (only shown in pinboard tab)
        if case .pinboard(let board) = viewModel.activeTab,
           let entry = board.entries.first(where: { $0.item?.id == item.id }) {
            Button("Remove from Pinboard", role: .destructive) {
                viewModel.removeEntry(entry)
            }
        }
    }

    private func promptNewPinboard(for item: ClipboardItem) {
        // Post a notification for the controller to handle the alert
        // (views can't present NSAlert directly)
        NotificationCenter.default.post(
            name: .createPinboardAndAdd,
            object: item
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: emptyStateIcon)
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text(emptyStateTitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text(emptyStateSubtitle)
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateIcon: String {
        if case .pinboard = viewModel.activeTab { return "pin" }
        return viewModel.searchQuery.isEmpty ? "clipboard" : "magnifyingglass"
    }

    private var emptyStateTitle: String {
        if case .pinboard(let b) = viewModel.activeTab {
            return "\(b.name) is empty"
        }
        return viewModel.searchQuery.isEmpty ? "No clipboard history yet" : "No results"
    }

    private var emptyStateSubtitle: String {
        if case .pinboard = viewModel.activeTab {
            return "Right-click any item in History to add it here"
        }
        return viewModel.searchQuery.isEmpty ? "Copy something to get started" : "Try a different search"
    }
}

// MARK: - Notification names for view → controller communication

extension Notification.Name {
    static let pasteAsPlainText    = Notification.Name("com.pasted.pasteAsPlainText")
    static let createPinboardAndAdd = Notification.Name("com.pasted.createPinboardAndAdd")
}
