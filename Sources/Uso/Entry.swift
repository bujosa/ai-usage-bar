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
        HStack(spacing: 5) {
            MenuMark()
            Text(store.menuTitle)
                .font(.system(size: 12, weight: .medium))
                .monospacedDigit()
                .lineLimit(1)
                .contentTransition(.opacity)
        }
        .onAppear { store.activate() }
    }
}

private struct MenuMark: View {
    var body: some View {
        Canvas { context, size in
            let bar = CGRect(x: 0, y: (size.height - 3) / 2, width: size.width, height: 3)
            let used = CGRect(x: 0, y: bar.minY, width: size.width * 0.68, height: bar.height)
            context.fill(Path(roundedRect: bar, cornerRadius: 1.5), with: .color(.primary.opacity(0.32)))
            context.fill(Path(roundedRect: used, cornerRadius: 1.5), with: .color(.primary))
        }
        .frame(width: 15, height: 8)
        .accessibilityHidden(true)
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
