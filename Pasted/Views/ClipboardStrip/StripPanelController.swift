import AppKit
import SwiftUI

// MARK: - Placeholder for ClipboardStripView (created by another agent)

/// Temporary placeholder view until the real ClipboardStripView is implemented.
private struct ClipboardStripPlaceholder: View {
    var body: some View {
        Text("Clipboard Strip")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - StripPanelController

/// Manages the floating NSPanel that hosts the clipboard strip overlay.
@MainActor
final class StripPanelController {
    private let store: ClipboardStore
    private let pasteService: PasteService
    private var panel: NSPanel?
    private var selectedIndex: Int = 0

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    init(store: ClipboardStore, pasteService: PasteService) {
        self.store = store
        self.pasteService = pasteService
    }

    // MARK: - Panel Lifecycle

    func toggle() {
        if isVisible {
            dismiss()
        } else {
            show()
        }
    }

    func show() {
        if panel == nil {
            panel = createPanel()
        }
        guard let panel else { return }

        positionPanel(panel)
        selectedIndex = 0
        panel.orderFrontRegardless()
    }

    func dismiss() {
        panel?.orderOut(nil)
    }

    // MARK: - Navigation (called from KeyboardShortcutManager)

    func selectPrevious() {
        guard selectedIndex > 0 else { return }
        selectedIndex -= 1
        // Selection state will be driven through the SwiftUI view model in a future update.
    }

    func selectNext() {
        selectedIndex += 1
        // Upper bound will be clamped when the SwiftUI view is wired up.
    }

    func confirmSelection() {
        do {
            let items = try store.fetchRecent(limit: 50)
            guard selectedIndex < items.count else { return }
            pasteService.paste(items[selectedIndex])
            dismiss()
        } catch {
            print("[StripPanelController] Confirm selection failed: \(error)")
        }
    }

    // MARK: - Panel Creation

    private func createPanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )

        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true

        // Visual effect background
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 16
        visualEffectView.layer?.masksToBounds = true

        // Host the SwiftUI view
        // Replace ClipboardStripPlaceholder with the real ClipboardStripView once available.
        let hostingView = NSHostingView(rootView: ClipboardStripPlaceholder())
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        visualEffectView.translatesAutoresizingMaskIntoConstraints = false

        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.addSubview(visualEffectView)
        containerView.addSubview(hostingView)

        NSLayoutConstraint.activate([
            visualEffectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            visualEffectView.topAnchor.constraint(equalTo: containerView.topAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),

            hostingView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostingView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostingView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostingView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])

        panel.contentView = containerView

        return panel
    }

    // MARK: - Positioning

    /// Centers the panel horizontally near the bottom of the active screen.
    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let panelWidth = screenFrame.width * 0.8
        let panelHeight: CGFloat = 180

        let x = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        let y = screenFrame.origin.y + 48 // 48pt from the bottom of the visible frame

        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
}
