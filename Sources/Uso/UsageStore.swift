import AppKit
import Foundation
import ServiceManagement

@MainActor
final class UsageStore: ObservableObject {
    @Published var providers: [ProviderSnapshot] = []
    @Published var hero: HeroState?
    @Published var menuTitle = "Usage"
    @Published var isRefreshing = false
    @Published var updatedAt: Date?
    @Published var opensAtLogin = false
    @Published var loginMessage: String?

    private var timer: Timer?
    private var ticker: Timer?
    private var tickerLines: [String] = []
    private var tickerIndex = 0
    private var task: Task<Void, Never>?
    private let service = UsageService()

    var showsLoginToggle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    var updatedLabel: String {
        guard let updatedAt else { return isRefreshing ? "Loading" : "" }
        let seconds = Int(Date().timeIntervalSince(updatedAt))
        if seconds < 15 { return "now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m ago" }
        return "\(minutes / 60)h ago"
    }

    func activate() {
        if showsLoginToggle {
            opensAtLogin = SMAppService.mainApp.status == .enabled
        }
        guard timer == nil else { return }
        refresh(force: true)
        timer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        ticker = Timer.scheduledTimer(withTimeInterval: 3.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.advanceTicker()
            }
        }
    }

    private func advanceTicker() {
        guard tickerLines.count > 1 else { return }
        tickerIndex = (tickerIndex + 1) % tickerLines.count
        menuTitle = tickerLines[tickerIndex]
    }

    private func syncTicker() {
        tickerLines = MenuTicker.lines(from: providers.filter { $0.tone == .ready })
        guard !tickerLines.isEmpty else {
            menuTitle = "Usage"
            return
        }
        tickerIndex = tickerIndex % tickerLines.count
        menuTitle = tickerLines[tickerIndex]
    }

    func refresh(force: Bool = false) {
        if !force, let updatedAt, Date().timeIntervalSince(updatedAt) < 45 { return }
        guard task == nil else { return }
        isRefreshing = true
        let baseline = providers.filter { $0.tone != .loading }
        if providers.isEmpty {
            providers = ProviderSnapshot.placeholders
        }
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            for await snapshot in self.service.loadIncremental() {
                self.apply(snapshot, keeping: baseline)
            }
            self.isRefreshing = false
            self.task = nil
        }
    }

    private func apply(_ snapshot: ProviderSnapshot, keeping baseline: [ProviderSnapshot]) {
        var item = snapshot
        if item.tone != .ready, let previous = baseline.first(where: { $0.id == item.id && $0.tone == .ready }) {
            var kept = previous
            kept.warning = item.note ?? "Couldn't refresh."
            item = kept
        }
        var next = providers
        if let index = next.firstIndex(where: { $0.id == item.id }) {
            next[index] = item
        } else {
            next.append(item)
        }
        next.sort { order($0.id) < order($1.id) }
        providers = next
        let ready = providers.filter { $0.tone == .ready }
        hero = Pressure.hero(from: ready)
        syncTicker()
        updatedAt = Date()
    }

    private func order(_ id: String) -> Int {
        switch id {
        case "grok": return 0
        case "cursor": return 1
        case "openai": return 2
        case "claude": return 3
        case "opencode": return 4
        default: return 9
        }
    }

    func allowClaudeKeychain() {
        guard task == nil else { return }
        isRefreshing = true
        task = Task { @MainActor [weak self] in
            guard let self else { return }
            let snapshot = await self.service.claudeWithPrompt()
            self.apply(snapshot, keeping: self.providers.filter { $0.tone != .loading })
            self.isRefreshing = false
            self.task = nil
        }
    }

    func setOpensAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            opensAtLogin = SMAppService.mainApp.status == .enabled
            loginMessage = nil
        } catch {
            opensAtLogin = SMAppService.mainApp.status == .enabled
            loginMessage = "macOS blocked open at login."
        }
    }

}
