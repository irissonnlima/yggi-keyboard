import SwiftUI
import YggiCore

/// Um widget da barra de menus, ligado ao estado real do teclado.
/// O desenho muda com o tamanho: quanto mais espaço, mais detalhe.
struct WidgetView: View {
    let slot: WidgetSlot
    var highlighted = false
    @Environment(KeyboardStore.self) private var store

    var body: some View {
        WidgetCard(title: slot.showTitle ? store.info(slot.kind).name : nil, highlighted: highlighted) {
            content
        }
    }

    private var cols: Int { slot.size.columns }
    private var tall: Bool { slot.size.rows > 1 }
    private var state: KeyboardState { store.state }

    @ViewBuilder private var content: some View {
        switch slot.kind {
        case .stagger: stagger
        case .staggerQuick: staggerQuick
        case .activeHost: activeHost
        case .hosts: hosts
        case .layer: layer
        case .battery: battery
        case .halves: halves
        case .brightness: brightness
        case .lightColor: lightColor
        case .today: today
        case .dailyGoal: dailyGoal
        case .heatmap: heatmap
        case .break: pause
        case .quickActions: quickActions
        case .customButton: customButton
        case .firmware: firmware
        }
    }

    // MARK: teclado

    private var isStaggered: Bool { state.staggerPercent > 0 }

    private var stagger: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 8) {
                if cols >= 3 || tall {
                    KeyboardGlyph(percent: state.staggerPercent, joined: state.halvesJoined)
                        .frame(width: tall ? 96 : 64, height: tall ? 36 : 22)
                }
                Text(isStaggered ? "Aberto" : "Ortho").font(.callout.weight(.semibold))
                Spacer(minLength: 0)
                staggerButton
            }
            PercentSlider(value: state.staggerPercent, label: "Abertura do stagger") { store.setStaggerLevel($0) }
                .disabled(!state.isConnected)
        }
    }

    private var staggerButton: some View {
        Button(isStaggered ? "Fechar" : "Abrir") { store.setStagger(!isStaggered) }
            .controlSize(.small)
            .disabled(!state.isConnected)
    }

    private var staggerQuick: some View {
        Button { store.setStagger(!isStaggered) } label: {
            VStack(spacing: 4) {
                KeyboardGlyph(percent: state.staggerPercent, joined: state.halvesJoined).frame(width: 40, height: 20)
                Text(isStaggered ? "Fechar" : "Abrir").font(.caption.weight(.medium))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!state.isConnected)
    }

    private var pairedHosts: [HostSlot] { state.hosts.filter(\.paired) }

    private var activeHost: some View {
        Button {
            guard let active = state.activeHost, !pairedHosts.isEmpty else { return }
            let i = pairedHosts.firstIndex { $0.index == active } ?? 0
            store.selectHost(pairedHosts[(i + 1) % pairedHosts.count].index)
        } label: {
            HStack(spacing: 8) {
                HostDots(hosts: pairedHosts, active: state.activeHost)
                if cols >= 2 {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(state.activeHostName ?? "—").font(.callout.weight(.semibold)).lineLimit(1)
                        Text("toque para o próximo").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!state.isConnected)
    }

    private var hosts: some View {
        VStack(spacing: 2) {
            ForEach(pairedHosts.prefix(tall ? 4 : 2), id: \.index) { host in
                let active = state.activeHost == host.index
                Button { store.selectHost(host.index) } label: {
                    HStack(spacing: 8) {
                        Text("\(host.index + 1)")
                            .font(.caption2.weight(.bold))
                            .frame(width: 18, height: 18)
                            .background(Circle().fill(active ? Color.accentColor : Color.secondary.opacity(0.18)))
                            .foregroundStyle(active ? .white : .primary)
                        Text(host.name ?? "Computador \(host.index + 1)").font(.callout).lineLimit(1)
                        Spacer(minLength: 0)
                        if host.isThisComputer { Text("este Mac").font(.caption2).foregroundStyle(.secondary) }
                    }
                    .frame(height: 22)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!state.isConnected)
            }
        }
    }

    private var layer: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(store.fnHeld ? "Fn" : "Base").font(.title3.weight(.semibold))
            Text(cols >= 2 ? "perfil Mac · camada ativa" : "Mac").font(.caption2).foregroundStyle(.secondary)
        }
    }

    // MARK: energia

    private var battery: some View {
        Group {
            if cols == 1 {
                let low = lowestBattery(state: state)
                VStack(alignment: .leading, spacing: 4) {
                    Text(low.map { "\($0.level)%" } ?? "—").font(.title3.weight(.semibold)).monospacedDigit()
                    LevelBar(level: low?.level ?? 0, low: low.map { isLowBattery(battery: $0) } ?? false)
                    Text("mais baixa").font(.caption2).foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 12) {
                    batteryHalf("Esq.", state.left)
                    batteryHalf("Dir.", state.right)
                    if cols >= 3 {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("E-reader").font(.caption2).foregroundStyle(.secondary)
                            Text(state.reader == .docked ? "carregando" : readerText).font(.callout)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func batteryHalf(_ title: String, _ half: HalfStatus) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(title).font(.caption2).foregroundStyle(.secondary)
                if half.battery?.charging == true { Image(systemName: "bolt.fill").font(.caption2).foregroundStyle(.green) }
            }
            Text(half.battery.map { "\($0.level)%" } ?? "—").font(.callout.weight(.semibold)).monospacedDigit()
            LevelBar(level: half.battery?.level ?? 0, low: half.battery.map { isLowBattery(battery: $0) } ?? false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var readerText: String {
        switch state.reader {
        case .docked: "encaixado"
        case .loose: "solto"
        case .absent: "sem e-reader"
        }
    }

    private var halves: some View {
        HStack(spacing: 8) {
            Image(systemName: state.halvesJoined ? "rectangle.split.2x1.fill" : "rectangle.split.2x1")
                .font(.title3).foregroundStyle(.yggiText)
            if cols >= 2 {
                VStack(alignment: .leading, spacing: 1) {
                    Text(state.halvesJoined ? "Metades juntas" : "Separadas").font(.callout.weight(.semibold))
                    Text("e-reader \(readerText)").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: luz

    private var brightness: some View {
        VStack(alignment: .leading, spacing: 6) {
            PercentSlider(value: store.sentLighting.brightness, label: "Brilho", symbols: ("sun.min", "sun.max.fill")) { b in
                store.changeLightingNow { $0.brightness = b }
            }
            if cols >= 3 {
                HStack(spacing: 6) {
                    ForEach([EffectKind.off, .static, .wave, .reactive], id: \.self) { kind in
                        let on = store.sentLighting.effect.kind == kind
                        Button(effectName(kind)) { store.changeLightingNow { $0.effect.kind = kind } }
                            .buttonStyle(.plain)
                            .font(.caption2.weight(on ? .semibold : .regular))
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Capsule().fill(on ? Color.accentColor.opacity(0.18) : .clear))
                    }
                }
            }
        }
        .disabled(!state.isConnected)
    }

    private func effectName(_ kind: EffectKind) -> String {
        switch kind {
        case .off: "Apagada"
        case .static: "Fixa"
        case .breathing: "Respira"
        case .wave: "Onda"
        case .rainbow: "Arco-íris"
        case .reactive: "Ao tocar"
        }
    }

    private var lightColor: some View {
        let palette = Array(lightingPalette().prefix(cols * 3))
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(18), spacing: 7), count: cols * 3), alignment: .leading, spacing: 7) {
            ForEach(Array(palette.enumerated()), id: \.offset) { _, rgb in
                let on = store.sentLighting.effect.color == rgb
                Button { store.changeLightingNow { $0.effect.color = rgb } } label: {
                    Circle().fill(Color(rgb))
                        .frame(width: 18, height: 18)
                        .overlay(Circle().strokeBorder(on ? Color.primary : .clear, lineWidth: 2).padding(-3))
                }
                .buttonStyle(.plain)
            }
        }
        .fixedSize()
        .disabled(!state.isConnected)
    }

    // MARK: escrita

    private var todayTotals: StatTotals? { store.statistics(.today)?.totals }

    private var today: some View {
        let t = todayTotals
        let items: [(String, String)] = [
            ("palavras", t.map { "\($0.words)" } ?? "—"),
            ("ppm", t.map { "\($0.avgWpm)" } ?? "—"),
            ("digitando", t.map { "\($0.typingMinutes) min" } ?? "—"),
            ("teclas", t.map { "\($0.keystrokes)" } ?? "—"),
        ]
        let shown = tall ? 4 : cols
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading), count: min(cols, shown)), alignment: .leading, spacing: 8) {
            ForEach(items.prefix(shown), id: \.0) { item in
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.1).font(.title3.weight(.semibold)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.7)
                    Text(item.0).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Meta de palavras do dia (fixa até a tela de metas existir).
    private let wordGoal = 1000.0

    private var dailyGoal: some View {
        let words = Double(todayTotals?.words ?? 0)
        let done = min(words / wordGoal, 1)
        return HStack(spacing: 10) {
            ZStack {
                Circle().stroke(.quaternary, lineWidth: 5)
                Circle().trim(from: 0, to: done).stroke(Color.accentColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(done * 100))%").font(.system(size: tall ? 15 : 10, weight: .semibold)).monospacedDigit()
            }
            .frame(width: tall ? 72 : 38, height: tall ? 72 : 38)
            if cols >= 2 {
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(Int(words)) de \(Int(wordGoal))").font(.callout.weight(.semibold)).monospacedDigit()
                    Text("palavras hoje").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var heatmap: some View {
        let counts = store.statistics(.today)?.keyCounts ?? []
        let max = counts.map(\.count).max() ?? 0
        var levels: [String: Int] = [:]
        for k in counts { levels[k.keyId] = Int(heatLevel(count: k.count, max: max)) }
        return HeatKeyboard(layout: store.layout, levels: levels,
                            stagger: Double(state.staggerPercent), separation: state.halvesJoined ? 0 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Pausa a cada 50 minutos digitando.
    private var pause: some View {
        let minutes = Int(todayTotals?.typingMinutes ?? 0)
        let left = 50 - minutes % 50
        return HStack(spacing: 8) {
            Image(systemName: "cup.and.saucer").font(.title3).foregroundStyle(.yggiText)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(left) min").font(.callout.weight(.semibold)).monospacedDigit()
                if cols >= 2 { Text("até a próxima pausa").font(.caption2).foregroundStyle(.secondary) }
            }
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: atalhos e sistema

    private var quickActions: some View {
        HStack(spacing: 6) {
            action("Yggi", "keyboard") { AppWindows.main(.overview) }
            action(store.sentLighting.effect.kind == .off ? "Acender" : "Apagar", "lightbulb") {
                store.changeLightingNow { $0.effect.kind = $0.effect.kind == .off ? .wave : .off }
            }
            .disabled(!state.isConnected)
            if cols >= 3 {
                action("Estatísticas", "chart.bar.xaxis") { AppWindows.main(.stats) }
            }
        }
    }

    private func action(_ title: String, _ symbol: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 14))
                Text(title).font(.caption2).lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 7).fill(Color.primary.opacity(0.05)))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// Por enquanto faz o mesmo que a tecla Yggi (trocar de computador).
    private var customButton: some View {
        Button { store.pressKey("L-yggi") } label: {
            VStack(spacing: 4) {
                Image(systemName: "star.circle.fill").font(.title2).foregroundStyle(.yggiText)
                Text("Tecla Yggi").font(.caption2)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var firmware: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ZMK").font(.callout.weight(.semibold))
            Text(store.simulator != nil ? "simulado" : "atualizado").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

/// O teclado inteiro em quadradinhos, sem legenda, pintado pelo uso de cada tecla.
/// Segue a forma de agora: colunas sobem com o stagger e as metades se afastam; anima entre os estados.
struct HeatKeyboard: View, @MainActor Animatable {
    let layout: KeyboardLayout
    /// Nível de calor (0 a 4, de `heatLevel`) por id de tecla.
    let levels: [String: Int]
    var stagger: Double
    var separation: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(stagger, separation) }
        set { (stagger, separation) = (newValue.first, newValue.second) }
    }

    /// Espaço entre as metades separadas, em u.
    private let splitGap = 1.0
    private let keyGap = 0.14

    var body: some View {
        Canvas { context, size in
            let keys = layout.keys
            guard let minX = keys.map({ Double($0.x) }).min(),
                  let maxX = keys.map({ Double($0.x + $0.w) }).max(),
                  let maxY = keys.map({ Double($0.y + $0.h) }).max() else { return }
            let maxLift = layout.columns.map { Double($0.liftAtMax) }.max() ?? 0
            // No layout a metade direita começa em x 12 e a esquerda termina em 11: juntas, encostam.
            let gap = splitGap * separation - 1
            let widthU = maxX - minX + gap
            let heightU = maxY + maxLift
            let scale = min(size.width / widthU, size.height / heightU)
            let ox = (size.width - widthU * scale) / 2
            let oy = (size.height - heightU * scale) / 2
            for key in keys {
                let lift = key.column.map { Double(layout.columns[Int($0)].liftAtMax) * stagger / 100 } ?? 0
                let shift = key.half == .right ? gap : 0
                let rect = CGRect(x: ox + (Double(key.x) - minX + shift + keyGap / 2) * scale,
                                  y: oy + (maxLift + Double(key.y) - lift + keyGap / 2) * scale,
                                  width: (Double(key.w) - keyGap) * scale,
                                  height: (Double(key.h) - keyGap) * scale)
                let level = levels[key.id]
                let color = level.map { StatsScreen.ramp[$0].0 } ?? Color.secondary.opacity(0.15)
                context.fill(Path(roundedRect: rect, cornerRadius: scale * 0.12), with: .color(color))
            }
        }
        .accessibilityLabel("Mapa de calor do teclado")
    }
}

/// Barrinha de 0 a 100%, com o valor escrito ao lado.
struct PercentSlider: View {
    let value: UInt8
    let label: String
    /// Símbolos nas pontas (mínimo, máximo); sem eles, só a barrinha e o número.
    var symbols: (String, String)? = nil
    let change: (UInt8) -> Void

    var body: some View {
        HStack(spacing: 6) {
            if let symbols { Image(systemName: symbols.0).font(.caption2).foregroundStyle(.secondary) }
            Slider(value: Binding(get: { Double(value) }, set: { change(UInt8($0.rounded())) }), in: 0...100)
                .controlSize(.mini)
                .labelsHidden()
                .accessibilityLabel(label)
                .accessibilityValue("\(value)%")
            if let symbols { Image(systemName: symbols.1).font(.caption2).foregroundStyle(.secondary) }
            Text("\(value)%")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)
        }
    }
}

/// Os três LEDs de computador da tecla Yggi.
struct HostDots: View {
    let hosts: [HostSlot]
    let active: UInt8?

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(active == UInt8(i) ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
        .accessibilityLabel("computador \((active ?? 0) + 1)")
    }
}
