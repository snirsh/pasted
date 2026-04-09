import SwiftUI

/// Horizontal tab bar showing "History" + one tab per pinboard.
/// Supports rename/delete via right-click context menu and creating new pinboards.
struct PinboardTabBar: View {
    @ObservedObject var viewModel: StripViewModel

    @State private var showNewPinboardAlert = false
    @State private var newPinboardName = ""
    @State private var renamingBoard: Pinboard? = nil
    @State private var renameText = ""

    var body: some View {
        HStack(spacing: 4) {
            // History tab
            tabButton(label: "History", systemImage: "clock", tab: .history)

            // Pinboard tabs
            ForEach(viewModel.pinboards) { board in
                tabButton(label: board.name, systemImage: "pin", tab: .pinboard(board))
                    .contextMenu {
                        Button("Rename…") {
                            renameText = board.name
                            renamingBoard = board
                        }
                        Divider()
                        Button("Delete Pinboard", role: .destructive) {
                            viewModel.deletePinboard(board)
                        }
                    }
            }

            // Add pinboard button
            Button {
                newPinboardName = ""
                showNewPinboardAlert = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help("New Pinboard")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .alert("New Pinboard", isPresented: $showNewPinboardAlert) {
            TextField("Name", text: $newPinboardName)
            Button("Create") {
                let name = newPinboardName.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty { viewModel.createPinboard(name: name) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert("Rename Pinboard", isPresented: Binding(
            get: { renamingBoard != nil },
            set: { if !$0 { renamingBoard = nil } }
        )) {
            TextField("Name", text: $renameText)
            Button("Rename") {
                if let board = renamingBoard {
                    let name = renameText.trimmingCharacters(in: .whitespaces)
                    if !name.isEmpty { viewModel.renamePinboard(board, to: name) }
                }
                renamingBoard = nil
            }
            Button("Cancel", role: .cancel) { renamingBoard = nil }
        }
    }

    @ViewBuilder
    private func tabButton(label: String, systemImage: String, tab: StripTab) -> some View {
        let isActive = viewModel.activeTab == tab
        Button {
            viewModel.switchTab(tab)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 10))
                Text(label)
                    .font(DesignTokens.Typography.cardBadgeMed)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                isActive
                    ? DesignTokens.Colors.selectionBorder.opacity(0.2)
                    : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(
                        isActive ? DesignTokens.Colors.selectionBorder : Color.clear,
                        lineWidth: 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? DesignTokens.Colors.selectionBorder : .secondary)
    }
}
