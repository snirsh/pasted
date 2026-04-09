import AppKit
import SwiftUI
import SwiftData

/// NSPanel subclass that allows becoming key window.
/// .nonactivatingPanel alone prevents clicks from activating the app, but also
/// blocks canBecomeKey — meaning text fields never get focus. This subclass
/// re-enables key status so SwiftUI @FocusState and text input work correctly.
private final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Manages the floating NSPanel that hosts the clipboard strip overlay.
@MainActor
final class StripPanelController {
    private let store: ClipboardStore
    private let pasteService: PasteService
    private let modelContext: ModelContext
    private let viewModel = StripViewModel()
    private var panel: NSPanel?

    /// The app that was frontmost before we showed the strip.
    /// Restored when the strip is dismissed so the user's context is not lost.
    private var previousApp: NSRunningApplication?

    /// Back-reference to the keyboard manager so we can update its visibility cache.
    weak var keyboardManager: KeyboardShortcutManager?

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    init(store: ClipboardStore, pasteService: PasteService, modelContext: ModelContext) {
        self.store = store
        self.pasteService = pasteService
        self.modelContext = modelContext
        setupNotificationObservers()
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: .pasteAsPlainText, object: nil, queue: .main
        ) { [weak self] note in
            guard let item = note.object as? ClipboardItem else { return }
            Task { @MainActor [weak self] in
                self?.pasteService.pasteAsPlainText(item)
                self?.dismiss()
            }
        }
        NotificationCenter.default.addObserver(
            forName: .createPinboardAndAdd, object: nil, queue: .main
        ) { [weak self] note in
            guard let item = note.object as? ClipboardItem else { return }
            Task { @MainActor [weak self] in
                self?.promptCreatePinboard(for: item)
            }
        }
    }

    private func promptCreatePinboard(for item: ClipboardItem) {
        let alert = NSAlert()
        alert.messageText = "New Pinboard"
        alert.informativeText = "Enter a name for the new pinboard:"
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        textField.placeholderString = "Name"
        alert.accessoryView = textField
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let name = textField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        viewModel.createPinboard(name: name)
        if let board = viewModel.pinboards.last {
            viewModel.addItem(item, to: board)
        }
    }

    // MARK: - Panel Lifecycle

    func toggle() {
        if isVisible { dismiss() } else { show() }
    }

    func show() {
        // Remember where focus was so we can restore it on dismiss
        previousApp = NSWorkspace.shared.frontmostApplication

        // Reload items from store each time the strip is shown
        viewModel.loadPinboards(context: modelContext)
        viewModel.reload(from: store)
        viewModel.selectedIndex = 0
        viewModel.startLiveUpdates()

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
        keyboardManager?.isStripVisible = true

        // makeKeyAndOrderFront makes the panel key so @FocusState and text fields work.
        // Since this is an LSUIElement (menu-bar-only) app, activating it has no
        // visible effect on the dock or app switcher.
        panel.makeKeyAndOrderFront(nil)

        // Signal SearchBarView to auto-focus after the panel is key
        viewModel.focusTrigger += 1

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
        keyboardManager?.isStripVisible = false
        viewModel.stopLiveUpdates()
        viewModel.searchQuery = SearchQuery()
        viewModel.isShowingPreview = false

        // Restore focus to the app the user was in before opening the strip
        previousApp?.activate()
        previousApp = nil

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

    func togglePreview() {
        guard viewModel.selectedItem != nil else { return }
        viewModel.isShowingPreview.toggle()
    }

    // MARK: - Panel Creation

    private func createPanel() -> NSPanel {
        let panel = KeyablePanel(
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
        let panelHeight: CGFloat = 320
        let x = screenFrame.origin.x + (screenFrame.width - panelWidth) / 2
        let y = screenFrame.origin.y + 48
        panel.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
}
