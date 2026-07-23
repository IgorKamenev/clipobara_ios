import AppKit
import SwiftUI

@MainActor
final class HistoryPanelController: NSObject, NSWindowDelegate {
    private final class HistoryPanel: NSPanel {
        override var canBecomeKey: Bool { true }
        override var canBecomeMain: Bool { false }
    }

    private let repository: ClipboardRepository
    private let restoreService: PasteboardRestoreService
    private let settings: AppSettings
    private let model = HistoryPanelModel()
    private let panel: HistoryPanel
    private var localEventMonitor: Any?
    private var globalEventMonitor: Any?
    private var previousApplication: NSRunningApplication?

    init(
        repository: ClipboardRepository,
        restoreService: PasteboardRestoreService,
        settings: AppSettings = .shared
    ) {
        self.repository = repository
        self.restoreService = restoreService
        self.settings = settings
        panel = HistoryPanel(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 235),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        configurePanel()
        installEventMonitors()
    }

    var isVisible: Bool {
        panel.isVisible
    }

    func toggle() {
        panel.isVisible ? close() : show()
    }

    func show() {
        previousApplication = NSWorkspace.shared.frontmostApplication
        repository.reload()
        model.reset()

        let screen = screenUnderMouse() ?? NSScreen.main ?? NSScreen.screens.first
        guard let screen else { return }
        let visibleFrame = screen.visibleFrame
        let width = min(max(visibleFrame.width * 0.92, 680), 1_280)
        let height: CGFloat = 235
        let destinationFrame = NSRect(
            x: visibleFrame.midX - width / 2,
            y: visibleFrame.minY + 14,
            width: width,
            height: height
        )
        let startFrame = destinationFrame.offsetBy(dx: 0, dy: -height - 20)

        panel.setFrame(startFrame, display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        panel.makeKey()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(destinationFrame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    func close() {
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                self?.panel.orderOut(nil)
                self?.returnFocusToPreviousApp()
            }
        })
    }

    func windowDidResignKey(_ notification: Notification) {
        close()
    }

    private func configurePanel() {
        panel.delegate = self
        panel.level = .popUpMenu
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.collectionBehavior = [
            .canJoinAllSpaces,
            .fullScreenAuxiliary,
            .ignoresCycle,
            .transient
        ]

        let rootView = HistoryPanelView(
            repository: repository,
            model: model,
            settings: settings,
            onRestore: { [weak self] item in
                self?.select(item)
            },
            onClose: { [weak self] in self?.close() }
        )
        panel.contentView = NSHostingView(rootView: rootView)
    }

    private func select(_ item: ClipboardItem) {
        guard restoreService.restore(item) else { return }

        if settings.moveSelectedClipToFront {
            repository.promoteToFront(item)
        }

        let shouldAutoPaste = settings.autoPasteOnSelect
        if shouldAutoPaste {
            hideImmediately()
            // Yield so key/mouse handling finishes before we bounce focus and paste.
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated {
                    self?.returnFocusToPreviousApp()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    MainActor.assumeIsolated {
                        if !AutoPasteService.paste() {
                            self?.presentAccessibilityHint()
                        }
                    }
                }
            }
        } else {
            close()
        }
    }

    /// Opening the panel focuses the SwiftUI search field, which activates the app
    /// and steals focus from the app the user was typing in. Hand activation back
    /// so the original text field is first responder again before Cmd-V arrives.
    private func returnFocusToPreviousApp() {
        guard NSApp.isActive else { return }
        if let target = previousApplication,
           !target.isTerminated,
           target.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            NSApp.yieldActivation(to: target)
            target.activate()
        } else {
            NSApp.hide(nil)
        }
    }

    private func presentAccessibilityHint() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Clipobara can't paste automatically"
        alert.informativeText = """
        Allow Clipobara to control the keyboard in \
        System Settings → Privacy & Security → Accessibility, then try again. \
        If Clipobara is already listed, remove it and add it back.
        """
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            AutoPasteService.openAccessibilitySettings()
        }
    }

    private func hideImmediately() {
        guard panel.isVisible else { return }
        panel.alphaValue = 0
        panel.orderOut(nil)
    }

    private func installEventMonitors() {
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard let self, panel.isVisible else { return event }
            switch event.keyCode {
            case 53:
                close()
                return nil
            case 123, 126:
                model.moveSelection(by: -1, in: repository.items)
                return nil
            case 124, 125:
                model.moveSelection(by: 1, in: repository.items)
                return nil
            case 36, 76:
                if let selectedItem = model.selectedItem(in: repository.items) {
                    select(selectedItem)
                }
                return nil
            default:
                return event
            }
        }

        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.close()
            }
        }
    }

    private func screenUnderMouse() -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
    }
}
