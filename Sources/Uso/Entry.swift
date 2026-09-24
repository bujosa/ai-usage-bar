import AppKit
import Combine
import SwiftUI

@main
enum Entry {
    static func main() {
        if CommandLine.arguments.contains("--print") {
            let group = DispatchGroup()
            group.enter()
            Task.detached {
                let snapshots = await UsageService().load()
                for snapshot in snapshots {
                    print(snapshot.debugSummary)
                }
                group.leave()
            }
            group.wait()
            return
        }
        UsoApp.main()
    }
}

@MainActor
enum SharedStore {
    static let store = UsageStore()
}

struct UsoApp: App {
    @NSApplicationDelegateAdaptor(UsoDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

enum AppExit {
    nonisolated(unsafe) static var requested = false
}

@MainActor
final class UsoDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: NSWindow?
    private var titleWatcher: AnyCancellable?
    private var suppressToggle = false
    private let centered = CommandLine.arguments.contains("--panel")

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        AppExit.requested ? .terminateNow : .terminateCancel
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        SharedStore.store.activate()
        installStatusItem()
        if centered {
            NSApp.setActivationPolicy(.regular)
            showPanel()
        }
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "UsoUsage"
        item.isVisible = true
        let button = item.button
        button?.image = Self.markImage()
        button?.imagePosition = .imageLeading
        button?.target = self
        button?.action = #selector(togglePanel)
        statusItem = item
        applyTitle(SharedStore.store.menuTitle)
        titleWatcher = SharedStore.store.$menuTitle.sink { [weak self] title in
            self?.applyTitle(title)
        }
    }

    private func applyTitle(_ title: String) {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        statusItem?.button?.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor
            ]
        )
    }

    @objc private func togglePanel() {
        if suppressToggle || panel?.isVisible == true {
            panel?.orderOut(nil)
            return
        }
        showPanel()
    }

    private func showPanel() {
        let window = panel ?? makePanel()
        panel = window
        resize(window)
        if centered {
            center(window)
        } else {
            placeUnderStatusItem(window)
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        for delay in [0.3, 1.2] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak window] in
                guard let self, let window else { return }
                self.resize(window)
                if self.centered {
                    self.center(window)
                } else {
                    self.placeUnderStatusItem(window)
                }
            }
        }
    }

    private func makePanel() -> NSWindow {
        let content = NSHostingView(rootView: PanelView().environmentObject(SharedStore.store))
        content.sizingOptions = .intrinsicContentSize
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 328, height: 420),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.identifier = NSUserInterfaceItemIdentifier("uso-panel")
        window.title = "Usage"
        window.isReleasedWhenClosed = false
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .statusBar
        window.hidesOnDeactivate = !centered
        window.collectionBehavior = [.transient, .ignoresCycle]
        window.isMovableByWindowBackground = true
        window.contentView = content
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            self?.suppressToggle = true
            window?.orderOut(nil)
            DispatchQueue.main.async {
                self?.suppressToggle = false
            }
        }
        return window
    }

    private func resize(_ window: NSWindow) {
        guard let content = window.contentView else { return }
        content.invalidateIntrinsicContentSize()
        let intrinsic = content.intrinsicContentSize.height
        let height = intrinsic > 1 ? intrinsic : content.fittingSize.height
        window.setContentSize(NSSize(width: 328, height: max(height, 200)))
    }

    private func center(_ window: NSWindow) {
        guard let visible = NSScreen.main?.visibleFrame else {
            window.center()
            return
        }
        let size = window.frame.size
        window.setFrameOrigin(NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        ))
    }

    private func placeUnderStatusItem(_ window: NSWindow) {
        guard let buttonWindow = statusItem?.button?.window else {
            window.center()
            return
        }
        let anchor = buttonWindow.frame
        let size = window.frame.size
        var origin = NSPoint(x: anchor.midX - size.width / 2, y: anchor.minY - size.height - 6)
        if let screen = buttonWindow.screen ?? NSScreen.main {
            let bounds = screen.visibleFrame
            origin.x = min(max(origin.x, bounds.minX + 8), bounds.maxX - size.width - 8)
        }
        window.setFrameOrigin(origin)
    }

    private static func markImage() -> NSImage {
        let image = NSImage(size: NSSize(width: 15, height: 8), flipped: false) { _ in
            NSColor.white.withAlphaComponent(0.35).setFill()
            NSBezierPath(roundedRect: NSRect(x: 0, y: 2.5, width: 15, height: 3), xRadius: 1.5, yRadius: 1.5).fill()
            NSColor.white.setFill()
            NSBezierPath(roundedRect: NSRect(x: 0, y: 2.5, width: 10, height: 3), xRadius: 1.5, yRadius: 1.5).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
