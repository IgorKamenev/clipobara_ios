import AppKit
import SwiftData

@MainActor
final class AppController {
    static let shared = AppController()

    let modelContainer: ModelContainer
    let settings: AppSettings
    let repository: ClipboardRepository
    let monitor: PasteboardMonitor
    let restoreService: PasteboardRestoreService
    let historyPanelController: HistoryPanelController
    let hotKeyService: GlobalHotKeyService

    private(set) var startupError: Error?
    private var hasStarted = false

    private init() {
        do {
            modelContainer = try ModelContainer(for: ClipboardItem.self)
        } catch {
            fatalError("Unable to initialize clipboard database: \(error)")
        }

        settings = .shared
        repository = ClipboardRepository(
            modelContainer: modelContainer,
            settings: settings
        )
        monitor = PasteboardMonitor(
            repository: repository,
            settings: settings
        )
        restoreService = PasteboardRestoreService(
            repository: repository,
            monitor: monitor
        )
        historyPanelController = HistoryPanelController(
            repository: repository,
            restoreService: restoreService
        )
        hotKeyService = GlobalHotKeyService()
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true
        monitor.start()
        do {
            try hotKeyService.register(shortcut: settings.historyShortcut) { [weak self] in
                self?.historyPanelController.toggle()
            }
        } catch {
            startupError = error
            let alert = NSAlert(error: error)
            alert.informativeText += "\nYou can still open history from the menu bar."
            alert.runModal()
        }
    }

    func updateHistoryShortcut(_ shortcut: GlobalShortcut) -> String? {
        guard shortcut != settings.historyShortcut else { return nil }
        do {
            try hotKeyService.register(shortcut: shortcut) { [weak self] in
                self?.historyPanelController.toggle()
            }
            settings.setHistoryShortcut(shortcut)
            return nil
        } catch {
            return error.localizedDescription
        }
    }
}
