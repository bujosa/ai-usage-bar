import AppKit
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
        MenuBarExtra {
            PanelView()
                .environmentObject(SharedStore.store)
        } label: {
            MenuTitle()
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuTitle: View {
    @ObservedObject private var store = SharedStore.store

    var body: some View {
        Text(store.menuTitle)
            .font(.system(size: 12, weight: .medium))
            .onAppear { store.activate() }
    }
}

final class UsoDelegate: NSObject, NSApplicationDelegate {
    var panel: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard CommandLine.arguments.contains("--panel") else { return }
        NSApp.setActivationPolicy(.regular)
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
        window.level = .floating
        window.hidesOnDeactivate = true
        window.collectionBehavior = [.transient, .ignoresCycle]
        window.isMovableByWindowBackground = true
        window.contentView = content
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: window,
            queue: .main
        ) { [weak window] _ in
            MainActor.assumeIsolated {
                window?.orderOut(nil)
            }
        }
        panel = window
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        for delay in [0.3, 2.0, 4.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                content.invalidateIntrinsicContentSize()
                let intrinsic = content.intrinsicContentSize.height
                let height = intrinsic > 1 ? intrinsic : content.fittingSize.height
                window.setContentSize(NSSize(width: 328, height: max(height, 200)))
                window.center()
            }
        }
    }
}
