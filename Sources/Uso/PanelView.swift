import AppKit
import SwiftUI

struct PanelView: View {
    @EnvironmentObject private var store: UsageStore
    @State private var selectedID: String?

    private var selected: ProviderSnapshot? {
        guard let selectedID else { return nil }
        return store.providers.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let provider = selected {
                DetailView(provider: provider)
                    .transition(.opacity)
            } else if store.providers.isEmpty {
                Text(store.isRefreshing ? "Reading accounts…" : "No data yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 28)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                list
                    .transition(.opacity)
            }
            if selected == nil {
                footer
            }
        }
        .frame(width: 328)
        .animation(.smooth(duration: 0.22), value: selectedID)
        .background {
            Button(action: hide) { Color.clear }
                .keyboardShortcut(.escape, modifiers: [])
                .disabled(selectedID != nil)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .background(GlassBackground())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .task {
            for window in NSApp.windows where window.identifier?.rawValue != "uso-panel" {
                window.isOpaque = false
                window.backgroundColor = .clear
            }
            store.activate()
            if selectedID == nil, let id = Self.requestedDetail,
               store.providers.contains(where: { $0.id == id }) {
                selectedID = id
            }
        }
        .onChange(of: store.providers.map(\.id)) { _, _ in
            if selectedID == nil, let id = Self.requestedDetail,
               store.providers.contains(where: { $0.id == id }) {
                selectedID = id
            }
            resizePreview()
        }
        .onChange(of: selectedID) { _, _ in
            resizePreview()
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.providers.enumerated()), id: \.element.id) { index, provider in
                Button {
                    selectedID = provider.id
                } label: {
                    ProviderRow(provider: provider)
                }
                .buttonStyle(RowButtonStyle())
                if index < store.providers.count - 1 {
                    Divider()
                        .padding(.leading, 16)
                        .opacity(0.55)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private var header: some View {
        HStack(spacing: 8) {
            if selected != nil {
                Button {
                    selectedID = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                        Text("Usage")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .keyboardShortcut(.escape, modifiers: [])
            } else {
                Text("Usage")
                    .font(.subheadline.weight(.semibold))
            }
            Spacer()
            if selected == nil, !store.updatedLabel.isEmpty {
                Text(store.updatedLabel)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Button {
                store.refresh(force: true)
            } label: {
                Group {
                    if store.isRefreshing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11, weight: .semibold))
                    }
                }
                .frame(width: 22, height: 22)
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .disabled(store.isRefreshing)
            .keyboardShortcut("r")
            .help("Refresh")
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            Divider().opacity(0.45)
            HStack {
                if store.showsLoginToggle {
                    Toggle("Open at login", isOn: Binding(
                        get: { store.opensAtLogin },
                        set: { store.setOpensAtLogin($0) }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            if let loginMessage = store.loginMessage {
                Text(loginMessage)
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 2)
        .padding(.bottom, 10)
    }

    private static var requestedDetail: String? {
        guard let index = CommandLine.arguments.firstIndex(of: "--detail"),
              CommandLine.arguments.indices.contains(index + 1)
        else { return nil }
        return CommandLine.arguments[index + 1]
    }

    private func hide() {
        NSApp.keyWindow?.orderOut(nil)
    }

    private func resizePreview() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { $0.identifier?.rawValue == "uso-panel" }),
                  let content = window.contentView
            else { return }
            content.invalidateIntrinsicContentSize()
            let intrinsic = content.intrinsicContentSize.height
            let height = intrinsic > 1 ? intrinsic : content.fittingSize.height
            window.setContentSize(NSSize(width: 328, height: max(height, 180)))
        }
    }
}

private struct ProviderRow: View {
    let provider: ProviderSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 8) {
                Circle()
                    .fill(Accent.color(for: provider.id))
                    .frame(width: 6, height: 6)
                Text(provider.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                Spacer(minLength: 8)
                Text(amount)
                    .font(.body.weight(.semibold).monospacedDigit())
                    .foregroundStyle(amountColor)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            if !caption.isEmpty {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .padding(.leading, 14)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(listBars) { bar in
                    VStack(alignment: .leading, spacing: 3) {
                        if listBars.count > 1 {
                            HStack {
                                Text(bar.label)
                                Spacer()
                                Text("\(Format.percent(max(0, 100 - bar.usedPercent))) left")
                                    .monospacedDigit()
                            }
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                        Meter(used: bar.usedPercent, accent: Accent.color(for: provider.id))
                    }
                }
            }
            .padding(.leading, 14)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private var amount: String {
        if provider.tone == .loading { return "…" }
        if provider.tone != .ready { return "—" }
        if provider.headline.contains("$") {
            return provider.headline.replacingOccurrences(of: " left", with: "")
        }
        if let used = provider.bars.first?.usedPercent {
            return Format.percent(max(0, 100 - used))
        }
        if let week = provider.chips.first(where: { $0.id == "week" }) {
            return week.value
        }
        return provider.headline
    }

    private var listBars: [MeterBar] {
        if provider.id == "cursor" {
            return provider.bars.filter { $0.id == "included" || $0.id == "auto" }
        }
        return Array(provider.bars.prefix(1))
    }

    private var amountColor: Color {
        guard let used = provider.bars.first?.usedPercent else { return .primary }
        if used >= 90 { return .red }
        if used >= 75 { return .orange }
        return .primary
    }

    private var caption: String {
        if provider.tone == .loading { return "Loading" }
        if provider.tone != .ready {
            return provider.note ?? "No data"
        }
        var bits: [String] = []
        let plan = provider.plan.split(separator: "·").first
            .map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        if !plan.isEmpty, plan != "Local" {
            bits.append(plan)
        }
        if provider.id != "cursor", let hot = provider.bars.dropFirst().first(where: { $0.usedPercent >= 99 }) {
            bits.append("\(hot.label) maxed")
        } else if provider.id != "cursor", let detail = provider.bars.first?.detail, !detail.isEmpty {
            bits.append(detail)
        } else if provider.bars.isEmpty, let week = provider.chips.first(where: { $0.id == "week" }) {
            bits.append("\(week.hint) in 7 days")
        }
        return bits.joined(separator: " · ")
    }
}

private struct DetailView: View {
    @EnvironmentObject private var store: UsageStore
    let provider: ProviderSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(provider.name)
                    .font(.title3.weight(.semibold))
                if !provider.plan.isEmpty {
                    Text(provider.plan)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            if provider.tone == .ready {
                Text(provider.headline)
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(headlineColor)
            }

            if provider.tone != .ready, let note = provider.note {
                Text(note)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if provider.id == "claude", note == "Keychain locked" {
                    Button("Allow access") {
                        store.allowClaudeKeychain()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }

            if !provider.bars.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(provider.bars) { bar in
                        DetailMeter(bar: bar, accent: Accent.color(for: provider.id))
                    }
                }
            }

            if !provider.chips.isEmpty {
                HStack(alignment: .top, spacing: 8) {
                    ForEach(provider.chips) { chip in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(chip.label)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(chip.value)
                                .font(.headline.monospacedDigit())
                            Text(chip.hint)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }

            if !provider.lines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(provider.lines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            if provider.tone == .ready, let note = provider.note {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let warning = provider.warning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 2)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var headlineColor: Color {
        guard let used = provider.bars.first?.usedPercent else { return .primary }
        if used >= 90 { return .red }
        if used >= 75 { return .orange }
        return .primary
    }
}

private struct DetailMeter: View {
    let bar: MeterBar
    let accent: Color

    var body: some View {
        let left = max(0, min(100, 100 - bar.usedPercent))
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(bar.label)
                    .font(.subheadline)
                Spacer(minLength: 8)
                Text("\(Format.percent(left)) left")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Meter(used: bar.usedPercent, accent: accent)
            if !bar.detail.isEmpty {
                Text(bar.detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct Meter: View {
    let used: Double
    let accent: Color

    var body: some View {
        let clamped = min(max(used, 0), 100)
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.08))
                Capsule()
                    .fill(fill)
                    .frame(width: max(clamped > 0 ? 3 : 0, geo.size.width * clamped / 100))
            }
        }
        .frame(height: 4)
    }

    private var fill: Color {
        if used >= 90 { return .red }
        if used >= 75 { return .orange }
        return accent
    }
}

private struct RowButtonStyle: ButtonStyle {
    @State private var hovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.08 : hovered ? 0.05 : 0))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
            )
            .onHover { hovered = $0 }
    }
}

private struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

enum Accent {
    static func color(for id: String) -> Color {
        switch id {
        case "grok": return Color(red: 0.62, green: 0.54, blue: 0.42)
        case "cursor": return Color(red: 0.45, green: 0.62, blue: 0.98)
        case "openai": return Color(red: 0.36, green: 0.72, blue: 0.48)
        case "claude": return Color(red: 0.86, green: 0.48, blue: 0.34)
        case "opencode": return Color(red: 0.28, green: 0.70, blue: 0.70)
        default: return Color.primary
        }
    }
}
