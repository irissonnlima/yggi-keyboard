import SwiftUI
import YggiCore

/// Balão que abre ao clicar no ícone da barra de menus: abas montadas com widgets.
/// Quais abas e widgets existem, e onde cada um fica, vem do núcleo (`MenuBarConfig`).
struct MenuBarView: View {
    @Environment(KeyboardStore.self) private var store
    var body: some View {
        let state = store.state
        let tab = store.currentMenuTab
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                YggiMark().frame(height: 16)
                Text("Yggi").font(.headline)
                Circle().fill(state.isConnected ? .green : .secondary).frame(width: 6, height: 6)
                Text(state.connectionText).font(.caption).foregroundStyle(.secondary)
                Spacer()
                if store.simulator != nil { SimulatedTag() }
                Button {
                    AppWindows.main(.menuBar)
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
        }
        .padding(12)
        .frame(width: GridMetrics.popover.width + 24)
        .onAppear {
            if store.menuBar.openFirstTab { store.menuTab = store.menuBar.tabs.first?.id }
        }
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
