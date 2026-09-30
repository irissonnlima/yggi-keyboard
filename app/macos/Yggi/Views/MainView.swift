import SwiftUI
import YggiCore

enum AppSection: Hashable {
    case overview, keys, lights, stats

    var title: String {
        switch self {
        case .overview: "Visão geral"
        case .keys: "Teclas e camadas"
        case .lights: "Luzes e efeitos"
        case .stats: "Estatísticas"
        }
    }

    var symbol: String {
        switch self {
        case .overview: "keyboard"
        case .keys: "square.3.layers.3d"
        case .lights: "lightbulb"
        case .stats: "chart.bar.xaxis"
        }
    }
}

/// Janela principal: barra lateral à esquerda, teclado à direita.
struct MainView: View {
    @Environment(KeyboardStore.self) private var store
    @State private var section: AppSection? = .overview

    var body: some View {
        NavigationSplitView {
            SidebarView(section: $section)
                .navigationSplitViewColumnWidth(min: 220, ideal: 232, max: 280)
        } detail: {
            Group {
                switch section ?? .overview {
                case .overview: OverviewScreen()
                case .keys: KeysScreen()
                case .lights: LightsScreen()
                case .stats: StatsScreen()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 1100, minHeight: 760)
    }
}

struct SidebarView: View {
    @Environment(KeyboardStore.self) private var store
    @Binding var section: AppSection?

    var body: some View {
        List(selection: $section) {
            Section("Yggi") {
                ForEach([AppSection.overview, .keys, .lights, .stats], id: \.self) { item in
                    Label(item.title, systemImage: item.symbol)
                        .badge(item == .lights && store.hasUnsentLighting ? Text("1") : nil)
                        .tag(item)
                }
            }
            Section("Computadores") {
                ForEach(store.state.hosts.filter(\.paired), id: \.index) { host in
                    Button {
                        store.selectHost(host.index)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: host.index == 0 ? "laptopcomputer" : (host.index == 1 ? "desktopcomputer" : "ipad"))
                                .foregroundStyle(.tint)
                                .frame(width: 18)
                            Text(host.name ?? "Computador \(host.index + 1)")
                                .lineLimit(1)
                            if host.isThisComputer {
                                Text("este Mac")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 5)
                                    .overlay(Capsule().strokeBorder(.secondary.opacity(0.5)))
                            }
                            Spacer()
                            if store.state.activeHost == host.index {
                                Circle().fill(.green).frame(width: 7, height: 7)
                                    .accessibilityLabel("ativo")
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!store.state.isConnected)
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            SidebarFooter()
        }
    }
}

private struct SidebarFooter: View {
    @Environment(KeyboardStore.self) private var store

    var body: some View {
        VStack(spacing: 8) {
            Divider()
            BatteryLine(title: "Esquerda", half: store.state.left)
            BatteryLine(title: "Direita", half: store.state.right)
            HStack(spacing: 6) {
                Circle().fill(store.state.isConnected ? .green : .secondary).frame(width: 7, height: 7)
                Text(store.state.connectionText)
                Spacer()
                if store.simulator != nil { SimulatedTag() }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

struct BatteryLine: View {
    let title: String
    let half: HalfStatus

    var body: some View {
        HStack(spacing: 8) {
            Text(title).font(.caption)
            Spacer()
            if let battery = half.battery {
                LevelBar(level: battery.level, low: isLowBattery(battery: battery))
                    .frame(width: 44)
                Text("\(battery.level)%")
                    .font(.caption.monospacedDigit())
                    .frame(width: 32, alignment: .trailing)
            } else {
                Text("—").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct LevelBar: View {
    let level: UInt8
    var low = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.quaternary)
                Capsule().fill(low ? Color.red : Color.green)
                    .frame(width: geo.size.width * CGFloat(level) / 100)
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

/// O teclado ocupando a largura disponível (até o tamanho natural).
struct FittedKeyboard<Content: View>: View {
    var maxUnit: CGFloat = 44
    @ViewBuilder var content: (CGFloat) -> Content

    var body: some View {
        GeometryReader { geo in
            let unit = min(maxUnit, geo.size.width / (980 / 44))
            content(unit)
                .frame(width: geo.size.width, height: 380 * unit / 44)
        }
        .aspectRatio(980 / 380, contentMode: .fit)
        .frame(maxWidth: 980 * maxUnit / 44)
    }
}
