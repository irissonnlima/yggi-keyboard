import SwiftUI
import YggiCore

enum LightsTab: String, CaseIterable, Identifiable {
    case effect = "Efeito"
    case paint = "Cores por tecla"
    case actions = "Teclas de ação"
    var id: String { rawValue }
}

/// Luzes e efeitos: um LED RGB em cada tecla, em três camadas
/// (efeito geral < cores por tecla < teclas de ação). O cálculo é do núcleo.
struct LightsScreen: View {
    @Environment(KeyboardStore.self) private var store
    @State private var tab: LightsTab = .effect
    @State private var brush = Rgb(r: 0xbf, g: 0x5a, b: 0xf2)
    @State private var selected: String?

    var body: some View {
        VStack(spacing: 12) {
            FittedKeyboard { unit in
                LiveKeyboard(selectedKey: tab == .actions ? selected : nil, unit: unit) { key in
                    tapped(key)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(alignment: .top, spacing: 12) {
                Group {
                    switch tab {
                    case .effect: EffectPanel()
                    case .paint: PaintPanel(brush: $brush)
                    case .actions: ActionsPanel(selected: $selected)
                    }
                }
                .frame(maxWidth: .infinity)
                .layoutPriority(1)

                Group {
                    if tab == .effect {
                        GeneralLightPanel()
                    } else {
                        SimulatePanel()
                    }
                }
                .frame(width: 300)
            }
            if let error = store.lastError {
                Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
            }
        }
        .padding(20)
        .navigationTitle("Luzes e efeitos")
        .navigationSubtitle("LED RGB em cada tecla")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("Camada", selection: $tab) {
                    ForEach(LightsTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button("Testar encaixe") { store.replayDock() }
                    .help("Mostra a onda de luz de quando o e-reader encaixa")
                if store.hasUnsentLighting {
                    Button("Descartar") { store.discardLighting() }
                }
                Button("Enviar ao teclado") { store.sendLighting() }
                    .buttonStyle(.borderedProminent)
                    .disabled(!store.hasUnsentLighting)
            }
        }
    }

    private func tapped(_ key: KeyDef) {
        switch tab {
        case .effect:
            break
        case .paint:
            store.lighting.togglePaint(key.id, brush)
        case .actions:
            if !store.lighting.actions.contains(where: { $0.keyId == key.id }) {
                store.lighting.actions.append(ActionRule(keyId: key.id, trigger: .always,
                                                         color: Rgb(r: 0xf2, g: 0xf2, b: 0xf7), mode: .solid))
            }
            selected = key.id
        }
    }
}

extension LightingConfig {
    mutating func togglePaint(_ id: String, _ color: Rgb) {
        if let i = keyColors.firstIndex(where: { $0.keyId == id }) {
            if keyColors[i].color == color {
                keyColors.remove(at: i)
            } else {
                keyColors[i].color = color
            }
        } else {
            keyColors.append(KeyColor(keyId: id, color: color))
        }
    }

    mutating func paint(_ ids: [String], _ color: Rgb) {
        for id in ids {
            if let i = keyColors.firstIndex(where: { $0.keyId == id }) {
                keyColors[i].color = color
            } else {
                keyColors.append(KeyColor(keyId: id, color: color))
            }
        }
    }
}

// MARK: - Efeito

private struct EffectPanel: View {
    @Environment(KeyboardStore.self) private var store

    private let kinds: [(EffectKind, String)] = [
        (.off, "Desligado"), (.static, "Estático"), (.breathing, "Respiração"),
        (.wave, "Onda"), (.rainbow, "Arco-íris"), (.reactive, "Ao tocar"),
    ]

    var body: some View {
        @Bindable var store = store
        let effect = store.lighting.effect
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(kinds, id: \.0) { kind, title in
                        EffectTile(kind: kind, title: title, color: effect.color, selected: effect.kind == kind) {
                            store.lighting.effect.kind = kind
                        }
                    }
                }
                if [.static, .breathing, .wave, .reactive].contains(effect.kind) {
                    HStack(spacing: 12) {
                        Text("Cor").foregroundStyle(.secondary)
                        ColorChooser(color: $store.lighting.effect.color)
                    }
                }
                HStack(spacing: 24) {
                    if [.breathing, .wave, .rainbow, .reactive].contains(effect.kind) {
                        LabeledContent("Velocidade") {
                            Picker("Velocidade", selection: $store.lighting.effect.speed) {
                                Text("lenta").tag(Speed.slow)
                                Text("média").tag(Speed.medium)
                                Text("rápida").tag(Speed.fast)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                    if effect.kind == .wave {
                        LabeledContent("Direção") {
                            Picker("Direção", selection: $store.lighting.effect.direction) {
                                Text("→").tag(WaveDirection.right)
                                Text("←").tag(WaveDirection.left)
                                Text("↑").tag(WaveDirection.up)
                                Text("do centro").tag(WaveDirection.fromCenter)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .fixedSize()
                        }
                    }
                    if effect.kind == .reactive {
                        Text("Clique nas teclas acima para ver o efeito.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

private struct EffectTile: View {
    let kind: EffectKind
    let title: String
    let color: Rgb
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                HStack(spacing: 3) {
                    ForEach(0..<5, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(dotColor(i))
                            .frame(width: 9, height: 9)
                    }
                }
                Text(title).font(.caption)
            }
            .frame(width: 92, height: 62)
            .background(RoundedRectangle(cornerRadius: 10).fill(selected ? AnyShapeStyle(.background) : AnyShapeStyle(.quinary)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func dotColor(_ i: Int) -> Color {
        let c = Color(color)
        switch kind {
        case .off: return .secondary.opacity(0.35)
        case .rainbow: return [Color.red, .orange, .green, .blue, .purple][i]
        case .wave: return c.opacity([0.25, 0.55, 1, 0.55, 0.25][i])
        case .breathing: return c.opacity(0.6)
        case .reactive: return i == 2 ? c : .secondary.opacity(0.35)
        case .static: return c
        }
    }
}

private struct GeneralLightPanel: View {
    @Environment(KeyboardStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Text("Geral").font(.headline)
                LabeledContent("Brilho") {
                    PercentSlider(value: store.lighting.brightness, label: "Brilho", symbols: ("sun.min", "sun.max.fill")) {
                        store.lighting.brightness = $0
                    }
                    .frame(width: 220)
                }
                Toggle("Onda de luz ao encaixar o e-reader", isOn: $store.lighting.waveOnDock)
                Toggle("Segurando fn, acender as teclas que têm função", isOn: $store.lighting.fnMap)
                Toggle("Apagar após 30 s sem digitar", isOn: $store.lighting.idleOff)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }
}

// MARK: - Cores por tecla

private struct PaintPanel: View {
    @Environment(KeyboardStore.self) private var store
    @Binding var brush: Rgb

    private let groups: [(String, [String])] = [
        ("Letras", ["L-q", "L-w", "L-e", "L-r", "L-t", "L-a", "L-s", "L-d", "L-f", "L-g", "L-z", "L-x", "L-c", "L-v", "L-b",
                    "R-y", "R-u", "R-i", "R-o", "R-p", "R-h", "R-j", "R-k", "R-l", "R-n", "R-m"]),
        ("Números", ["L-grave", "L-1", "L-2", "L-3", "L-4", "L-5", "R-6", "R-7", "R-8", "R-9", "R-0", "R-minus", "R-equal"]),
        ("Fileira F", ["L-esc", "L-F1", "L-F2", "L-F3", "L-F4", "L-F5", "L-F6", "R-F7", "R-F8", "R-F9", "R-F10", "R-F11", "R-F12", "R-lock"]),
        ("Modificadores", ["L-tab", "L-caps", "L-shift", "R-shift", "L-fn", "L-ctrl", "L-opt", "L-cmd", "R-cmd"]),
        ("Polegar", ["L-del", "L-space", "R-space", "R-ret", "R-up", "R-left", "R-down", "R-right"]),
        ("Setas", ["R-up", "R-left", "R-down", "R-right"]),
    ]

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Text("Pincel").foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                    ColorChooser(color: $brush)
                    Text(brush.hex).font(.callout.monospaced()).foregroundStyle(.secondary)
                }
                HStack(spacing: 8) {
                    Text("Pintar grupo").foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
                    ForEach(groups, id: \.0) { name, ids in
                        Button(name) { store.lighting.paint(ids, brush) }
                    }
                }
                HStack {
                    let count = store.lighting.keyColors.count
                    Text("Clique numa tecla acima para pintar; de novo com a mesma cor para apagar."
                         + (count > 0 ? " \(count) \(count == 1 ? "tecla" : "teclas") com cor própria." : ""))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Limpar cores") { store.lighting.keyColors.removeAll() }
                        .disabled(store.lighting.keyColors.isEmpty)
                }
            }
        }
    }
}

// MARK: - Teclas de ação

private struct ActionsPanel: View {
    @Environment(KeyboardStore.self) private var store
    @Binding var selected: String?

    var body: some View {
        @Bindable var store = store
        Card(padding: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Teclas de ação").font(.headline)
                    Spacer()
                    Text("Clique numa tecla acima para transformá-la em tecla de ação")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(Array(store.lighting.actions.enumerated()), id: \.offset) { i, rule in
                    HStack(spacing: 10) {
                        Button(keyName(rule.keyId)) { selected = rule.keyId }
                            .buttonStyle(.plain)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Hardware.legend)
                            .frame(minWidth: 70, minHeight: 24)
                            .background(RoundedRectangle(cornerRadius: 6).fill(Hardware.keyModifier))
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(rule.color), lineWidth: 1.5))
                        Picker("Quando acende", selection: $store.lighting.actions[i].trigger) {
                            Text("acende sempre").tag(ActionTrigger.always)
                            Text("com caps lock ligado").tag(ActionTrigger.capsLock)
                            Text("segurando fn").tag(ActionTrigger.fnHeld)
                            Text("ao parear").tag(ActionTrigger.pairing)
                            Text("com bateria baixa").tag(ActionTrigger.lowBattery)
                        }
                        .labelsHidden()
                        .fixedSize()
                        ColorChooser(color: $store.lighting.actions[i].color, size: 16)
                        Spacer()
                        Picker("Modo", selection: $store.lighting.actions[i].mode) {
                            Text("fixo").tag(LightMode.solid)
                            Text("pulsa").tag(LightMode.pulse)
                            Text("pisca").tag(LightMode.blink)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .fixedSize()
                        Button {
                            store.lighting.actions.remove(at: i)
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("Remover \(keyName(rule.keyId)) das teclas de ação")
                    }
                    .padding(.vertical, 3)
                    .padding(.horizontal, 6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(selected == rule.keyId ? Color.accentColor.opacity(0.1) : .clear))
                }
            }
        }
    }

    private func keyName(_ id: String) -> String {
        store.layout.keys.first { $0.id == id }?.label ?? id
    }
}

private struct SimulatePanel: View {
    @Environment(KeyboardStore.self) private var store

    var body: some View {
        @Bindable var store = store
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Simular").font(.headline)
                if let sim = store.simulator {
                    Toggle("Caps lock ligado", isOn: Binding(get: { store.state.capsLock }, set: { sim.setCapsLock(on: $0) }))
                    Toggle("Segurando fn", isOn: $store.fnHeld)
                    Toggle("Pareando", isOn: Binding(get: { store.state.pairing }, set: { sim.setPairing(on: $0) }))
                    Toggle("Bateria baixa", isOn: Binding(
                        get: { lowestBattery(state: store.state).map { isLowBattery(battery: $0) } ?? false },
                        set: { sim.loadScenario(scenario: $0 ? .lowBattery : .normal) }
                    ))
                }
                Text("Ordem das camadas").font(.headline).padding(.top, 4)
                layer(1, "Teclas de ação, sempre por cima", .primary)
                layer(2, "Cores por tecla", .secondary)
                layer(3, "Efeito geral, por baixo", .tertiary)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
        }
    }

    private func layer(_ n: Int, _ text: String, _ style: HierarchicalShapeStyle) -> some View {
        HStack(spacing: 8) {
            Text("\(n)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                .frame(width: 18, height: 18)
                .background(RoundedRectangle(cornerRadius: 5).fill(style))
            Text(text).font(.callout)
        }
    }
}
