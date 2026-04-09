import AppKit
import SwiftUI
import SwiftData

// MARK: - StripPanelController

/// Manages the floating NSPanel that hosts the clipboard strip overlay.
@MainActor
final class StripPanelController {
    private let store: ClipboardStore
    private let pasteService: PasteService
    private var panel: NSPanel?
    private var selectedIndex: Int = 0
    private var keyMonitor: Any?

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

        // Start with panel offset down 20pt and fully transparent
        var startFrame = panel.frame
        startFrame.origin.y -= 20
        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0

        panel.orderFrontRegardless()

        // Install local keyboard monitor for arrow keys, Return, Escape
        installKeyMonitor()

        // Animate slide-up + fade-in
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            var targetFrame = startFrame
            targetFrame.origin.y += 20
            panel.animator().setFrame(targetFrame, display: true)
            panel.animator().alphaValue = 1
        })
    }

    func dismiss() {
        guard let panel else { return }

        // Animate slide-down + fade-out, then order out
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            var targetFrame = panel.frame
            targetFrame.origin.y -= 20
            panel.animator().setFrame(targetFrame, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            panel?.orderOut(nil)
        })

        removeKeyMonitor()
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

    func confirmSelectionPlainText() {
        do {
            let items = try store.fetchRecent(limit: 50)
            guard selectedIndex < items.count else { return }
            pasteService.pasteAsPlainText(items[selectedIndex])
            dismiss()
        } catch {
            print("[StripPanelController] Plain text paste failed: \(error)")
        }
    }

    /// Selects the item at the given index (0-based) in the strip.
    func selectIndex(_ index: Int) {
        selectedIndex = index
    }

    // MARK: - Keyboard Monitor

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isVisible else { return event }
            switch Int(event.keyCode) {
            case 123: // Left arrow
                self.selectPrevious()
                return nil
            case 124: // Right arrow
                self.selectNext()
                return nil
            case 36: // Return
                if event.modifierFlags.contains(.shift) {
                    self.confirmSelectionPlainText()
                } else {
                    self.confirmSelection()
                }
                return nil
            case 53: // Escape
                self.dismiss()
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
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

        // Host the SwiftUI view with the shared model container injected.
        // Because this NSPanel lives outside the SwiftUI scene hierarchy,
        // @Query in ClipboardStripView won't have a modelContainer unless
        // we explicitly provide one via .modelContainer().
        let pasteService = self.pasteService
        let stripView = ClipboardStripView(
            onPaste: { [weak self] item in
                pasteService.paste(item)
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        .modelContainer(SharedModelContainer.instance)

        let hostingView = NSHostingView(rootView: stripView)
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
        let panelHeight: CGFloat = 280

        let x = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        let y = screenFrame.origin.y + 48 // 48pt from the bottom of the visible frame

        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
}
