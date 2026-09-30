import SwiftUI
import YggiCore

/// Visão geral: o teclado como está agora (stagger, metades, e-reader, luzes) e o estado.
struct OverviewScreen: View {
    @Environment(KeyboardStore.self) private var store

    var body: some View {
        let state = store.state
        VStack(spacing: 16) {
            Spacer(minLength: 0)
            FittedKeyboard { unit in
                LiveKeyboard(unit: unit)
            }
            Text("Toque na tecla \(Text("yggi").foregroundStyle(.yggiText).fontWeight(.semibold)) para ir ao próximo computador. O botão ao lado dos LEDs solta as colunas.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let error = store.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            Spacer(minLength: 0)

            Grid(horizontalSpacing: 12) {
                GridRow {
                    StatusCard(title: "Conexão") {
                        HStack(spacing: 8) {
                            Circle().fill(state.isConnected ? .green : .secondary).frame(width: 8, height: 8)
                            Text(state.connectionText)
                        }
                    } footer: {
                        Text(state.halvesJoined ? "Metades encaixadas pelo pogo" : "Metades separadas, sem fio")
                    }
                    StatusCard(title: "Computador ativo") {
                        Text(state.activeHostName ?? "—")
                    } footer: {
                        if let index = state.activeHost {
                            let me = state.hosts.first { $0.index == index }?.isThisComputer == true
                            Text("Vaga \(index + 1) de \(hostSlotCount()) · \(me ? "este Mac" : "outro computador")")
                        } else {
                            Text("Conecte o teclado para ver")
                        }
                    }
                    batteryCard("Bateria esquerda", state.left)
                    batteryCard("Bateria direita", state.right)
                }
            }
        }
        .padding(24)
        .navigationTitle("Visão geral")
        .navigationSubtitle(subtitle)
        .toolbar { OverviewToolbar() }
    }

    private var subtitle: String {
        let state = store.state
        guard state.isConnected else { return state.connectionText }
        return "Conectado por \(state.connectionText)" + (state.activeHostName.map { " · \($0)" } ?? "")
    }

    private func batteryCard(_ title: String, _ half: HalfStatus) -> some View {
        StatusCard(title: title) {
            if let battery = half.battery {
                HStack(spacing: 6) {
                    Text("\(battery.level)%").monospacedDigit()
                    if battery.charging {
                        Image(systemName: "bolt.fill").foregroundStyle(.yellow).font(.callout)
                            .accessibilityLabel("carregando")
                    }
                }
            } else {
                Text(half.reachable || !store.state.isConnected ? "—" : "sem sinal")
                    .foregroundStyle(.secondary)
            }
        } footer: {
            if let battery = half.battery {
                LevelBar(level: battery.level, low: isLowBattery(battery: battery))
            } else {
                Text(store.state.isConnected ? "A metade não responde" : " ")
            }
        }
    }
}

struct StatusCard<Value: View, Footer: View>: View {
    let title: String
    @ViewBuilder var value: Value
    @ViewBuilder var footer: Footer

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                value.font(.title3.weight(.semibold))
                footer.font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

/// Controles do estado físico. No teclado real vêm dos sensores; aqui mexem no simulador.
struct OverviewToolbar: ToolbarContent {
    @Environment(KeyboardStore.self) private var store

    var body: some ToolbarContent {
        let state = store.state
        let simulated = store.simulator != nil
        ToolbarItemGroup(placement: .primaryAction) {
            Picker("Colunas", selection: Binding(
                get: { state.staggerPercent > 0 },
                set: { store.setStagger($0) }
            )) {
                Text("Ortho").tag(false)
                Text("Stagger").tag(true)
            }
            .pickerStyle(.segmented)
            .help("Colunas em ortho ou soltas pela mola")

            Picker("Quanto de stagger", selection: Binding(
                get: { store.staggerLevel },
                set: { store.setStaggerLevel($0) }
            )) {
                Text("50%").tag(UInt8(50))
                Text("100%").tag(UInt8(100))
                Text("150%").tag(UInt8(150))
            }
            .pickerStyle(.segmented)
            .opacity(state.staggerPercent > 0 ? 1 : 0.5)

            Picker("Metades", selection: Binding(
                get: { state.halvesJoined },
                set: { store.setHalvesJoined($0) }
            )) {
                Text("Juntas").tag(true)
                Text("Separadas").tag(false)
            }
            .pickerStyle(.segmented)

            Picker("E-reader", selection: Binding(
                get: { state.reader },
                set: { store.setReader($0) }
            )) {
                Text("Encaixado").tag(ReaderState.docked)
                Text("Solto").tag(ReaderState.loose)
                Text("Sem e-reader").tag(ReaderState.absent)
            }
            .pickerStyle(.segmented)

            if simulated {
                SimulatorMenu()
            }
        }
    }
}

/// O que o teclado de verdade faria sozinho: cenários, cabo, conexão, pareamento.
struct SimulatorMenu: View {
    @Environment(KeyboardStore.self) private var store

    var body: some View {
        if let sim = store.simulator {
            Menu {
                Menu("Cenário") {
                    Button("Normal") { sim.loadScenario(scenario: .normal) }
                    Button("Bateria baixa") { sim.loadScenario(scenario: .lowBattery) }
                    Button("Carregando no USB") { sim.loadScenario(scenario: .charging) }
                    Button("Metade direita sem sinal") { sim.loadScenario(scenario: .rightHalfOffline) }
                    Button("Com outro computador") { sim.loadScenario(scenario: .otherComputer) }
                    Button("Desconectado") { sim.loadScenario(scenario: .disconnected) }
                }
                Divider()
                Button("Tocar a tecla Yggi") { sim.tapYggiKey() }
                Toggle("Pareando", isOn: Binding(get: { store.state.pairing }, set: { sim.setPairing(on: $0) }))
                Toggle("Caps lock", isOn: Binding(get: { store.state.capsLock }, set: { sim.setCapsLock(on: $0) }))
                Toggle("Cabo USB-C", isOn: Binding(get: { sim.isUsb() }, set: { sim.setUsb(plugged: $0) }))
                Toggle("Metade direita ligada", isOn: Binding(get: { sim.isRightHalfOn() }, set: { sim.setRightHalfOn(on: $0) }))
                Toggle("Tempo passando", isOn: Binding(get: { sim.isAnimated() }, set: { sim.setAnimated(animated: $0) }))
                Divider()
                if store.state.isConnected {
                    Button("Desconectar") { store.disconnect() }
                } else {
                    Button("Conectar") { store.connect() }
                }
            } label: {
                Label("Simulador", systemImage: "slider.horizontal.3")
            }
            .help("Simulador do teclado")
        }
    }
}
