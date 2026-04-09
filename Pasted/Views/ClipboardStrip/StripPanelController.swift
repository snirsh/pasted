import AppKit
import SwiftUI
import SwiftData

/// Manages the floating NSPanel that hosts the clipboard strip overlay.
@MainActor
final class StripPanelController {
    private let store: ClipboardStore
    private let pasteService: PasteService
    private let viewModel = StripViewModel()
    private var panel: NSPanel?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    init(store: ClipboardStore, pasteService: PasteService) {
        self.store = store
        self.pasteService = pasteService
    }

    // MARK: - Panel Lifecycle

    func toggle() {
        if isVisible { dismiss() } else { show() }
    }

    func show() {
        // Reload items from store each time the strip is shown
        viewModel.reload(from: store)
        viewModel.selectedIndex = 0

        if panel == nil {
            panel = createPanel()
        }
        guard let panel else { return }

        positionPanel(panel)

        // Animate in: start offset + transparent
        var startFrame = panel.frame
        startFrame.origin.y -= 20
        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            var target = startFrame
            target.origin.y += 20
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 1
        }

    }

    func dismiss() {
        guard let panel else { return }

        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            var target = panel.frame
            target.origin.y -= 20
            panel.animator().setFrame(target, display: true)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak panel] in
            panel?.orderOut(nil)
        })
    }

    // MARK: - Navigation

    func selectPrevious() { viewModel.moveLeft() }
    func selectNext() { viewModel.moveRight() }

    func confirmSelection() {
        guard let item = viewModel.selectedItem else { return }
        pasteService.paste(item)
        dismiss()
    }

    func confirmSelectionPlainText() {
        guard let item = viewModel.selectedItem else { return }
        pasteService.pasteAsPlainText(item)
        dismiss()
    }

    func selectIndex(_ index: Int) {
        viewModel.select(at: index)
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

        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 16
        visualEffectView.layer?.masksToBounds = true

        let pasteService = self.pasteService
        let stripView = ClipboardStripView(
            viewModel: viewModel,
            onPaste: { [weak self] item in
                pasteService.paste(item)
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )

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

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelWidth = screenFrame.width * 0.8
        let panelHeight: CGFloat = 280
        let x = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        let y = screenFrame.origin.y + 48
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
}
