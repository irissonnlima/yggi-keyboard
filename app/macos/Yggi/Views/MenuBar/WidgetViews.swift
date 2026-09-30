import SwiftUI
import YggiCore

/// Formato do espaço de um widget. Cada widget tem um desenho para cada formato,
/// deitado (2×1, 3×1) ou em pé (1×2), além do pequeno e do grande.
enum WidgetForm {
    /// 1×1: só o essencial.
    case small
    /// 2×1 e 3×1: em linha.
    case wide
    /// 1×2: empilhado.
    case tall
    /// 2×2 e 3×2: com mais detalhe.
    case large

    init(_ size: WidgetSize) {
        switch (size.columns, size.rows) {
        case (1, 1): self = .small
        case (1, _): self = .tall
        case (_, 1): self = .wide
        default: self = .large
        }
    }
}

/// Um widget da barra de menus, ligado ao estado real do teclado.
struct WidgetView: View {
    let slot: WidgetSlot
    var highlighted = false
    @Environment(KeyboardStore.self) private var store

    var body: some View {
        WidgetCard(title: slot.showTitle ? store.info(slot.kind).name : nil, highlighted: highlighted) {
            content
        }
    }

    private var form: WidgetForm { WidgetForm(slot.size) }
    private var cols: Int { slot.size.columns }
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

    // MARK: peças comuns

    /// Número grande com legenda embaixo.
    private func stat(_ value: String, _ caption: String, big: Bool = false) -> some View {
        VStack(spacing: 0) {
            Text(value).font(big ? .title2.weight(.semibold) : .title3.weight(.semibold))
                .monospacedDigit().lineLimit(1).minimumScaleFactor(0.6)
            Text(caption).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    /// Título e subtítulo lado a lado com um ícone (formato deitado).
    private func line(_ title: String, _ subtitle: String?) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title).font(.callout.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
            if let subtitle { Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1) }
        }
    }

    // MARK: teclado

    private var isStaggered: Bool { state.staggerPercent > 0 }
    private var staggerText: String { isStaggered ? "Aberto \(state.staggerPercent)%" : "Ortho" }
    private var glyph: KeyboardGlyph { KeyboardGlyph(percent: state.staggerPercent, joined: state.halvesJoined) }

    private var staggerButton: some View {
        Button(isStaggered ? "Fechar" : "Abrir") { store.setStagger(!isStaggered) }
            .controlSize(.small)
            .disabled(!state.isConnected)
    }

    private func staggerSlider(showValue: Bool = true) -> some View {
        PercentSlider(value: state.staggerPercent, label: "Abertura do stagger", showValue: showValue) { store.setStaggerLevel($0) }
            .disabled(!state.isConnected)
    }

    @ViewBuilder private var stagger: some View {
        switch form {
        case .small:
            staggerQuick
        case .wide:
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    if cols >= 3 { glyph.frame(width: 64, height: 22) }
                    Text(staggerText).font(.callout.weight(.semibold)).lineLimit(1)
                    Spacer(minLength: 0)
                    staggerButton
                }
                staggerSlider()
            }
        case .tall:
            VStack(spacing: 8) {
                glyph.frame(width: 80, height: 28)
                Text(staggerText).font(.callout.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.8)
                staggerSlider(showValue: false)
                staggerButton
            }
        case .large:
            VStack(spacing: 10) {
                glyph.frame(width: cols >= 3 ? 190 : 150, height: 52)
                HStack {
                    Text(staggerText).font(.callout.weight(.semibold))
                    Spacer(minLength: 0)
                    staggerButton
                }
                staggerSlider()
            }
        }
    }

    private var staggerQuick: some View {
        Button { store.setStagger(!isStaggered) } label: {
            Group {
                switch form {
                case .wide, .large:
                    HStack(spacing: 10) {
                        glyph.frame(width: 56, height: 22)
                        line(isStaggered ? "Fechar" : "Abrir", isStaggered ? "colunas abertas" : "colunas alinhadas")
                    }
                case .small, .tall:
                    VStack(spacing: form == .tall ? 10 : 4) {
                        glyph.frame(width: form == .tall ? 72 : 44, height: form == .tall ? 28 : 18)
                        Text(isStaggered ? "Fechar" : "Abrir").font(.caption.weight(.medium))
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!state.isConnected)
    }

    private var pairedHosts: [HostSlot] { state.hosts.filter(\.paired) }

    private func nextHost() {
        guard let active = state.activeHost, !pairedHosts.isEmpty else { return }
        let i = pairedHosts.firstIndex { $0.index == active } ?? 0
        store.selectHost(pairedHosts[(i + 1) % pairedHosts.count].index)
    }

    private var activeHost: some View {
        Button(action: nextHost) {
            Group {
                switch form {
                case .small:
                    VStack(spacing: 5) {
                        HostDots(hosts: pairedHosts, active: state.activeHost)
                        Text(state.activeHostName ?? "—").font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                    }
                case .wide, .large:
                    HStack(spacing: 10) {
                        HostDots(hosts: pairedHosts, active: state.activeHost)
                        line(state.activeHostName ?? "—", "toque para o próximo")
                    }
                case .tall:
                    VStack(spacing: 8) {
                        HostNumber(number: Int(state.activeHost ?? 0) + 1, active: true, size: 34)
                        Text(state.activeHostName ?? "—").font(.caption.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
                        HostDots(hosts: pairedHosts, active: state.activeHost)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!state.isConnected)
    }

    @ViewBuilder private var hosts: some View {
        switch form {
        case .wide:
            // Deitado: um botão por computador, lado a lado.
            HStack(spacing: 6) {
                ForEach(pairedHosts.prefix(3), id: \.index) { host in
                    Button { store.selectHost(host.index) } label: {
                        HStack(spacing: 5) {
                            HostNumber(number: Int(host.index) + 1, active: state.activeHost == host.index, size: 18)
                            if cols >= 3 {
                                Text(host.name ?? "Computador").font(.caption).lineLimit(1).minimumScaleFactor(0.8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .disabled(!state.isConnected)
        case .tall, .small:
            // Em pé: um embaixo do outro, número e nome curto.
            VStack(spacing: 6) {
                ForEach(pairedHosts.prefix(3), id: \.index) { host in
                    Button { store.selectHost(host.index) } label: {
                        VStack(spacing: 2) {
                            HostNumber(number: Int(host.index) + 1, active: state.activeHost == host.index, size: 20)
                            Text(host.name ?? "Computador").font(.caption2).lineLimit(1).minimumScaleFactor(0.7)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .disabled(!state.isConnected)
        case .large:
            VStack(spacing: 4) {
                ForEach(pairedHosts.prefix(4), id: \.index) { host in
                    Button { store.selectHost(host.index) } label: {
                        HStack(spacing: 8) {
                            HostNumber(number: Int(host.index) + 1, active: state.activeHost == host.index, size: 20)
                            Text(host.name ?? "Computador \(host.index + 1)").font(.callout).lineLimit(1)
                            Spacer(minLength: 0)
                            if host.isThisComputer { Text("este Mac").font(.caption2).foregroundStyle(.secondary) }
                        }
                        .frame(height: 24)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .disabled(!state.isConnected)
        }
    }

    @ViewBuilder private var layer: some View {
        let name = store.fnHeld ? "Fn" : "Base"
        switch form {
        case .small:
            stat(name, "Mac")
        case .wide, .large:
            HStack(spacing: 10) {
                Image(systemName: "square.3.layers.3d").font(.title3).foregroundStyle(.yggiText)
                line(name, "perfil Mac · camada ativa")
            }
        case .tall:
            VStack(spacing: 8) {
                Image(systemName: "square.3.layers.3d").font(.title).foregroundStyle(.yggiText)
                stat(name, "perfil Mac")
            }
        }
    }

    // MARK: energia

    private func low(_ battery: Battery?) -> Bool { battery.map { isLowBattery(battery: $0) } ?? false }

    @ViewBuilder private var battery: some View {
        switch form {
        case .small:
            let lowest = lowestBattery(state: state)
            VStack(spacing: 4) {
                Text(lowest.map { "\($0.level)%" } ?? "—").font(.title3.weight(.semibold)).monospacedDigit()
                LevelBar(level: lowest?.level ?? 0, low: low(lowest)).frame(width: 60)
            }
        case .wide:
            HStack(spacing: 12) {
                batteryHalf("Esq.", state.left)
                batteryHalf("Dir.", state.right)
                if cols >= 3 {
                    stat(state.reader == .docked ? "carregando" : readerText, "e-reader")
                        .frame(maxWidth: .infinity)
                }
            }
        case .tall:
            // Em pé: duas barras verticais, uma por metade.
            HStack(spacing: 14) {
                verticalBattery("E", state.left)
                verticalBattery("D", state.right)
            }
        case .large:
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    batteryHalf("Esquerda", state.left)
                    batteryHalf("Direita", state.right)
                }
                HStack(spacing: 6) {
                    Image(systemName: "book.closed").foregroundStyle(.secondary)
                    Text("E-reader \(state.reader == .docked ? "carregando" : readerText)").font(.caption)
                    Spacer(minLength: 0)
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
            LevelBar(level: half.battery?.level ?? 0, low: low(half.battery))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func verticalBattery(_ title: String, _ half: HalfStatus) -> some View {
        VStack(spacing: 4) {
            VerticalLevel(level: half.battery?.level ?? 0, low: low(half.battery))
                .frame(width: 14)
            Text(half.battery.map { "\($0.level)%" } ?? "—").font(.caption.weight(.semibold)).monospacedDigit()
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var readerText: String {
        switch state.reader {
        case .docked: "encaixado"
        case .loose: "solto"
        case .absent: "sem e-reader"
        }
    }

    @ViewBuilder private var halves: some View {
        let symbol = state.halvesJoined ? "rectangle.split.2x1.fill" : "rectangle.split.2x1"
        let title = state.halvesJoined ? "Juntas" : "Separadas"
        switch form {
        case .small:
            VStack(spacing: 4) {
                Image(systemName: symbol).font(.title3).foregroundStyle(.yggiText)
                Text(title).font(.caption.weight(.medium))
            }
        case .wide, .large:
            HStack(spacing: 10) {
                glyph.frame(width: 56, height: 22)
                line(state.halvesJoined ? "Metades juntas" : "Metades separadas", "e-reader \(readerText)")
            }
        case .tall:
            VStack(spacing: 8) {
                glyph.frame(width: 80, height: 28)
                Text(title).font(.callout.weight(.semibold))
                Text("e-reader \(readerText)").font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
    }

    // MARK: luz

    private func setBrightness(_ b: UInt8) { store.changeLightingNow { $0.brightness = b } }

    private var effects: some View {
        let kinds: [EffectKind] = [.off, .static, .wave, .reactive]
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: form == .large && cols == 2 ? 2 : 4), spacing: 4) {
            ForEach(kinds, id: \.self) { kind in
                let on = store.sentLighting.effect.kind == kind
                Button(effectName(kind)) { store.changeLightingNow { $0.effect.kind = kind } }
                    .buttonStyle(.plain)
                    .font(.caption2.weight(on ? .semibold : .regular))
                    .padding(.horizontal, 6).padding(.vertical, 3)
                    .frame(maxWidth: .infinity)
                    .background(Capsule().fill(on ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.04)))
            }
        }
    }

    @ViewBuilder private var brightness: some View {
        let value = store.sentLighting.brightness
        Group {
            switch form {
            case .small, .wide:
                VStack(spacing: 6) {
                    PercentSlider(value: value, label: "Brilho", symbols: ("sun.min", "sun.max.fill"), change: setBrightness)
                    if cols >= 3 { effects }
                }
            case .tall:
                // Em pé: barra vertical, como o controle de brilho do macOS.
                VStack(spacing: 6) {
                    Image(systemName: "sun.max.fill").font(.caption).foregroundStyle(.secondary)
                    VerticalPercentBar(value: value, label: "Brilho", change: setBrightness)
                        .frame(width: 26)
                    Text("\(value)%").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                }
            case .large:
                VStack(spacing: 10) {
                    PercentSlider(value: value, label: "Brilho", symbols: ("sun.min", "sun.max.fill"), change: setBrightness)
                    effects
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

    @ViewBuilder private var lightColor: some View {
        let palette = lightingPalette()
        let current = store.sentLighting.effect.color
        switch form {
        case .small:
            // Uma cor só; tocar passa para a próxima.
            Button {
                let i = palette.firstIndex(of: current) ?? -1
                let next = palette[(i + 1) % palette.count]
                store.changeLightingNow { $0.effect.color = next }
            } label: {
                Circle().fill(Color(current)).frame(width: 30, height: 30)
                    .overlay(Circle().strokeBorder(.primary.opacity(0.2)))
            }
            .buttonStyle(.plain)
            .disabled(!state.isConnected)
        default:
            let perRow = form == .tall ? 2 : (form == .large ? 4 : cols * 3)
            let count = form == .tall ? 6 : (form == .large ? 8 : cols * 3)
            let dot: CGFloat = form == .large ? 26 : 18
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(dot), spacing: 9), count: perRow), spacing: 9) {
                ForEach(Array(palette.prefix(count).enumerated()), id: \.offset) { _, rgb in
                    Button { store.changeLightingNow { $0.effect.color = rgb } } label: {
                        Circle().fill(Color(rgb))
                            .frame(width: dot, height: dot)
                            .overlay(Circle().strokeBorder(current == rgb ? Color.primary : .clear, lineWidth: 2).padding(-3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .fixedSize()
            .disabled(!state.isConnected)
        }
    }

    // MARK: escrita

    private var todayTotals: StatTotals? { store.statistics(.today)?.totals }

    @ViewBuilder private var today: some View {
        let t = todayTotals
        let items: [(String, String)] = [
            (t.map { "\($0.words)" } ?? "—", "palavras"),
            (t.map { "\($0.avgWpm)" } ?? "—", "ppm"),
            (t.map { "\($0.typingMinutes) min" } ?? "—", "digitando"),
            (t.map { "\($0.keystrokes)" } ?? "—", "teclas"),
        ]
        switch form {
        case .small:
            stat(items[0].0, items[0].1)
        case .wide:
            HStack(spacing: 8) {
                ForEach(items.prefix(cols), id: \.1) { stat($0.0, $0.1).frame(maxWidth: .infinity) }
            }
        case .tall:
            VStack(spacing: 8) {
                ForEach(items.prefix(3), id: \.1) { stat($0.0, $0.1) }
            }
        case .large:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                ForEach(items, id: \.1) { stat($0.0, $0.1, big: true) }
            }
        }
    }

    /// Meta de palavras do dia (fixa até a tela de metas existir).
    private let wordGoal = 1000.0

    @ViewBuilder private var dailyGoal: some View {
        let words = Double(todayTotals?.words ?? 0)
        let done = min(words / wordGoal, 1)
        let caption = "\(Int(words)) de \(Int(wordGoal))"
        switch form {
        case .small:
            GoalRing(done: done, size: 38)
        case .wide:
            HStack(spacing: 10) {
                GoalRing(done: done, size: 38)
                line(caption, "palavras hoje")
            }
        case .tall:
            VStack(spacing: 8) {
                GoalRing(done: done, size: 64)
                Text(caption).font(.caption.weight(.semibold)).monospacedDigit()
                Text("palavras hoje").font(.caption2).foregroundStyle(.secondary)
            }
        case .large:
            HStack(spacing: 14) {
                GoalRing(done: done, size: 84)
                line(caption, "palavras hoje")
            }
        }
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
    @ViewBuilder private var pause: some View {
        let minutes = Int(todayTotals?.typingMinutes ?? 0)
        let left = 50 - minutes % 50
        let icon = Image(systemName: "cup.and.saucer").foregroundStyle(.yggiText)
        switch form {
        case .small:
            VStack(spacing: 4) {
                icon.font(.title3)
                Text("\(left) min").font(.caption.weight(.semibold)).monospacedDigit()
            }
        case .wide, .large:
            HStack(spacing: 10) {
                icon.font(.title3)
                line("\(left) min", "até a próxima pausa")
            }
        case .tall:
            VStack(spacing: 8) {
                GoalRing(done: Double(minutes % 50) / 50, size: 56, label: "\(left)")
                Text("min até a pausa").font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
    }

    // MARK: atalhos e sistema

    private var actions: [(String, String, () -> Void)] {
        [
            ("Yggi", "keyboard", { AppWindows.main(.overview) }),
            (store.sentLighting.effect.kind == .off ? "Acender" : "Apagar", "lightbulb", {
                store.changeLightingNow { $0.effect.kind = $0.effect.kind == .off ? .wave : .off }
            }),
            ("Estatísticas", "chart.bar.xaxis", { AppWindows.main(.stats) }),
            ("Ajustes", "gearshape", { AppWindows.settings() }),
        ]
    }

    @ViewBuilder private var quickActions: some View {
        switch form {
        case .small, .wide:
            HStack(spacing: 6) {
                ForEach(actions.prefix(cols), id: \.0) { action($0.0, $0.1, run: $0.2) }
            }
        case .tall:
            VStack(spacing: 6) {
                ForEach(actions.prefix(3), id: \.0) { action($0.0, $0.1, run: $0.2) }
            }
        case .large:
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 2), spacing: 6) {
                ForEach(actions, id: \.0) { action($0.0, $0.1, run: $0.2).frame(height: 54) }
            }
        }
    }

    private func action(_ title: String, _ symbol: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 14))
                Text(title).font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
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
            Group {
                switch form {
                case .wide, .large:
                    HStack(spacing: 10) {
                        Image(systemName: "star.circle.fill").font(.title2).foregroundStyle(.yggiText)
                        line("Tecla Yggi", "troca de computador")
                    }
                case .small, .tall:
                    VStack(spacing: form == .tall ? 8 : 4) {
                        Image(systemName: "star.circle.fill").font(form == .tall ? .largeTitle : .title2).foregroundStyle(.yggiText)
                        Text("Tecla Yggi").font(.caption2)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder private var firmware: some View {
        let status = store.simulator != nil ? "simulado" : "atualizado"
        switch form {
        case .small, .tall:
            VStack(spacing: 4) {
                Image(systemName: "cpu").font(.title3).foregroundStyle(.yggiText)
                stat("ZMK", status)
            }
        case .wide, .large:
            HStack(spacing: 10) {
                Image(systemName: "cpu").font(.title3).foregroundStyle(.yggiText)
                line("ZMK", status)
            }
        }
    }
}

/// Número do computador numa bolinha (acesa se for o ativo).
struct HostNumber: View {
    let number: Int
    let active: Bool
    var size: CGFloat = 20

    var body: some View {
        Text("\(number)")
            .font(.system(size: size * 0.5, weight: .bold))
            .frame(width: size, height: size)
            .background(Circle().fill(active ? Color.accentColor : Color.secondary.opacity(0.18)))
            .foregroundStyle(active ? .white : .primary)
    }
}

/// Anel de progresso com o número no meio.
struct GoalRing: View {
    let done: Double
    var size: CGFloat = 38
    var label: String? = nil

    var body: some View {
        ZStack {
            Circle().stroke(.quaternary, lineWidth: size / 8)
            Circle().trim(from: 0, to: done)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: size / 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label ?? "\(Int(done * 100))%")
                .font(.system(size: size * 0.26, weight: .semibold)).monospacedDigit()
        }
        .frame(width: size, height: size)
    }
}

/// Nível de 0 a 100 numa barra em pé (bateria em pé).
struct VerticalLevel: View {
    let level: UInt8
    var low = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Capsule().fill(.quaternary)
                Capsule().fill(low ? Color.red : Color.green)
                    .frame(height: geo.size.height * CGFloat(level) / 100)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Barrinha em pé de 0 a 100%, arrastável (como o brilho no Centro de Controle).
struct VerticalPercentBar: View {
    let value: UInt8
    let label: String
    let change: (UInt8) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.08))
                RoundedRectangle(cornerRadius: 8).fill(Color.accentColor.opacity(0.85))
                    .frame(height: geo.size.height * CGFloat(value) / 100)
            }
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0).onChanged { g in
                let v = 1 - g.location.y / geo.size.height
                change(UInt8((min(max(v, 0), 1) * 100).rounded()))
            })
        }
        .accessibilityElement()
        .accessibilityLabel(label)
        .accessibilityValue("\(value)%")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: change(UInt8(min(Int(value) + 10, 100)))
            case .decrement: change(UInt8(max(Int(value) - 10, 0)))
            @unknown default: break
            }
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
    var showValue = true
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
            if showValue {
                Text("\(value)%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .trailing)
            }
        }
    }
}

/// A marca da tecla Yggi em miniatura: a perninha do computador ativo acesa.
struct HostDots: View {
    let hosts: [HostSlot]
    let active: UInt8?

    var body: some View {
        let mark = yggiMark()
        let lit = yggiKeyLitLegs(activeHost: active)
        ZStack {
            ForEach(Array(mark.capsules.enumerated()), id: \.offset) { i, capsule in
                MarkShape(drawing: MarkDrawing(width: mark.width, height: mark.height, capsules: [capsule], dimmed: false))
                    .fill(lit[i] ? Color.accentColor : Color.secondary.opacity(0.3))
            }
        }
        .aspectRatio(CGFloat(mark.width / mark.height), contentMode: .fit)
        .frame(width: 22)
        .animation(.easeInOut(duration: 0.2), value: active)
        .accessibilityLabel("computador \((active ?? 0) + 1)")
    }
}
