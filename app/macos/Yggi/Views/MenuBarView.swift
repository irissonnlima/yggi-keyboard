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

/// Janelinha que abre ao clicar no ícone da barra de menus: abas montadas com widgets.
/// Quais abas e widgets existem, e onde cada um fica, vem do núcleo (`MenuBarConfig`).
struct MenuBarView: View {
    @Environment(KeyboardStore.self) private var store
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        let state = store.state
        let tab = store.currentMenuTab
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(state.isConnected ? .green : .secondary).frame(width: 7, height: 7)
                Text("Yggi").font(.headline)
                Text(state.connectionText).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if store.simulator != nil { SimulatedTag() }
                Button {
                    store.openSection(.menuBar)
                    openMain()
                } label: {
                    Image(systemName: "slider.horizontal.3")
                }
                .buttonStyle(.borderless)
                .help("Editar abas e widgets")
            }

            if store.menuBar.tabs.count > 1 {
                TabChips(tabs: store.menuBar.tabs, current: tab.id) { store.menuTab = $0 }
            }

            if case .disconnected = state.connection {
                Button("Conectar") { store.connect() }
            }

            if tab.widgets.isEmpty {
                Text("Aba vazia. Adicione widgets em Yggi › Barra de menus.")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(width: GridMetrics.popover.width, height: 60)
                    .background(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator, style: StrokeStyle(lineWidth: 1, dash: [4])))
            } else {
                WidgetGrid(tab: tab) { slot, _ in WidgetView(slot: slot) }
            }

            if let error = store.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.red)
            }

            Divider()
            VStack(alignment: .leading, spacing: 2) {
                MenuRow(title: "Abrir Yggi…") { openMain() }
                MenuRow(title: "Ajustes…") {
                    openSettings()
                    NSApp.activate()
                }
                MenuRow(title: "Sair") { NSApp.terminate(nil) }
            }
        }
        .padding(12)
        .frame(width: GridMetrics.popover.width + 24)
        .onAppear {
            if store.menuBar.openFirstTab { store.menuTab = store.menuBar.tabs.first?.id }
        }
    }

    private func openMain() {
        openWindow(id: WindowID.main)
        NSApp.activate()
    }
}

/// Abas no topo do popover, no estilo do controle segmentado do macOS.
struct TabChips: View {
    let tabs: [MenuTab]
    let current: UInt32
    var dropTarget: UInt32? = nil
    let select: (UInt32) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(tabs, id: \.id) { tab in
                let on = tab.id == current
                Button { select(tab.id) } label: {
                    Text(tab.name)
                        .font(.caption.weight(on ? .semibold : .regular))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 22)
                        .background(RoundedRectangle(cornerRadius: 6).fill(on ? Color(nsColor: .controlBackgroundColor) : .clear)
                            .shadow(color: .black.opacity(on ? 0.12 : 0), radius: 1, y: 0.5))
                        .overlay(RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Color.accentColor, lineWidth: dropTarget == tab.id ? 2 : 0))
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.07)))
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
