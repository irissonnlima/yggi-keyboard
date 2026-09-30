import SwiftUI
import YggiCore

/// Ícone na barra de menus. Mostra a porcentagem quando alguma bateria está baixa.
struct MenuBarLabel: View {
    let state: KeyboardState
    @Environment(\.openWindow) private var openWindow
    @MainActor private static var openedAtLaunch = false

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: state.isConnected ? "keyboard" : "keyboard.badge.ellipsis")
            if let battery = lowestBattery(state: state), isLowBattery(battery: battery) {
                Text("\(battery.level)%")
            }
        }
        .task {
            // Aberto pela pessoa (não no login, que usa --hidden): mostra a janela uma vez.
            guard !Self.openedAtLaunch, !CommandLine.arguments.contains("--hidden") else { return }
            Self.openedAtLaunch = true
            openWindow(id: WindowID.main)
            NSApp.activate()
        }
    }
}

/// Janelinha que abre ao clicar no ícone da barra de menus.
struct MenuBarView: View {
    @Environment(KeyboardStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let state = store.state
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Yggi").font(.headline)
                Spacer()
                if store.simulator != nil { SimulatedTag() }
            }

            HStack(spacing: 8) {
                batteryTile("Esquerda", state.left)
                batteryTile("Direita", state.right)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Computador").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.bottom, 2)
                ForEach(state.hosts.filter(\.paired), id: \.index) { host in
                    HostRow(host: host, active: state.activeHost == host.index) {
                        store.selectHost(host.index)
                    }
                    .disabled(!state.isConnected)
                }
            }

            HStack(spacing: 8) {
                Circle().fill(state.isConnected ? .green : .secondary).frame(width: 7, height: 7)
                Text(statusLine).font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)

            if case .disconnected = state.connection {
                Button("Conectar") { store.connect() }
            }
            if let error = store.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red)
            }

            Divider()
            VStack(alignment: .leading, spacing: 2) {
                MenuRow(title: "Abrir Yggi…") {
                    openWindow(id: WindowID.main)
                    NSApp.activate()
                }
                MenuRow(title: "Ajustes…") {
                    openSettings()
                    NSApp.activate()
                }
                MenuRow(title: "Sair") { NSApp.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: 320)
    }

    private var statusLine: String {
        let state = store.state
        guard state.isConnected else { return state.connectionText }
        let columns = state.staggerPercent > 0 ? "stagger \(state.staggerPercent)%" : "colunas em ortho"
        return "\(state.connectionText) · \(columns)"
    }

    private func batteryTile(_ title: String, _ half: HalfStatus) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            if let battery = half.battery {
                Text("\(battery.level)%").font(.title3.weight(.semibold)).monospacedDigit()
                LevelBar(level: battery.level, low: isLowBattery(battery: battery))
            } else {
                Text(store.state.isConnected ? "sem sinal" : "—").font(.title3).foregroundStyle(.secondary)
                LevelBar(level: 0)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 8).fill(.background))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
    }
}

private struct HostRow: View {
    let host: HostSlot
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Text("\(host.index + 1)")
                    .font(.caption.weight(.semibold))
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(active ? Color.accentColor : Color.secondary.opacity(0.18)))
                    .foregroundStyle(active ? .white : .primary)
                Text(host.name ?? "Computador \(host.index + 1)")
                if host.isThisComputer {
                    Text("este Mac")
                        .font(.caption2).foregroundStyle(.secondary)
                        .padding(.horizontal, 5)
                        .overlay(Capsule().strokeBorder(.secondary.opacity(0.5)))
                }
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 30)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

private struct MenuRow: View {
    let title: String
    let action: () -> Void
    @State private var hover = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .frame(height: 26)
                .background(RoundedRectangle(cornerRadius: 6).fill(hover ? Color.primary.opacity(0.08) : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hover = $0 }
    }
}
