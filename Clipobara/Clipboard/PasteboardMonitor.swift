import AppKit
import Foundation

@MainActor
final class PasteboardMonitor {
    private let pasteboard: NSPasteboard
    private let repository: ClipboardRepository
    private let settings: AppSettings
    private var timer: Timer?
    private var lastChangeCount: Int
    private var ignoredChangeCount: Int?

    init(
        pasteboard: NSPasteboard = .general,
        repository: ClipboardRepository,
        settings: AppSettings = .shared
    ) {
        self.pasteboard = pasteboard
        self.repository = repository
        self.settings = settings
        self.lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard timer == nil else { return }
        lastChangeCount = pasteboard.changeCount
        let timer = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func ignoreCurrentPasteboardChange() {
        ignoredChangeCount = pasteboard.changeCount
        lastChangeCount = pasteboard.changeCount
    }

    func poll() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        if ignoredChangeCount == changeCount {
            ignoredChangeCount = nil
            return
        }

        guard settings.isMonitoringEnabled else { return }
        let sourceApplication = NSWorkspace.shared.frontmostApplication
        guard sourceApplication?.bundleIdentifier != Bundle.main.bundleIdentifier,
              !settings.isExcluded(bundleIdentifier: sourceApplication?.bundleIdentifier),
              let snapshot = PasteboardSnapshot.capture(
                from: pasteboard,
                sourceApplication: sourceApplication
              ) else {
            return
        }

        repository.save(snapshot)
    }
}
