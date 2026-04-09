import SwiftUI
import SwiftData

/// The main horizontal clipboard strip displaying recent clipboard items.
struct ClipboardStripView: View {
    @ObservedObject var viewModel: StripViewModel

    var onPaste: (ClipboardItem) -> Void
    var onDismiss: () -> Void

    var body: some View {
        Group {
            if viewModel.items.isEmpty {
                emptyState
            } else {
                stripContent
            }
        }
        .frame(height: 256)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Clipboard History, \(viewModel.items.count) items")
    }

    // MARK: - Strip Content

    private var stripContent: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(Array(viewModel.items.enumerated()), id: \.element.id) { index, item in
                        ClipboardItemPreview(item: item, position: index + 1, totalCount: viewModel.items.count)
                            .frame(width: 200, height: 240)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(viewModel.selectedIndex == index
                                          ? Color.accentColor.opacity(0.2)
                                          : Color.clear)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(viewModel.selectedIndex == index
                                            ? Color.accentColor
                                            : Color.clear, lineWidth: 2.5)
                            )
                            .id(index)
                            .contentShape(Rectangle())
                            .onTapGesture(count: 2) {
                                viewModel.select(at: index)
                                onPaste(item)
                            }
                            .onTapGesture(count: 1) {
                                viewModel.select(at: index)
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: viewModel.selectedIndex) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.15)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clipboard")
                .font(.system(size: 32))
                .foregroundStyle(.tertiary)
            Text("No clipboard history yet")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
            Text("Copy something to get started")
                .font(.system(size: 12))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
