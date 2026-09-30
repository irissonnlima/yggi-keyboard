import SwiftUI
import YggiCore

/// Cor fixa de uma tecla no mapa de calor.
struct KeyFill: Equatable {
    var background: Color
    var legend: Color
}

/// O teclado Yggi desenhado de cima, a partir do layout do núcleo.
/// Anima o stagger, a separação das metades e o encaixe do e-reader quando o estado muda.
struct KeyboardView: View {
    let layout: KeyboardLayout
    let state: KeyboardState
    /// Luz de cada tecla neste quadro (vem do `LightingEngine`).
    var glows: [String: KeyGlow] = [:]
    /// Mapa de calor: pinta as próprias teclas.
    var fills: [String: KeyFill]? = nil
    var selectedKey: String? = nil
    var showReader = true
    var onKey: (KeyDef) -> Void = { _ in }
    var onRelease: () -> Void = {}

    /// Tamanho de uma tecla (1u), em pontos.
    var unit: CGFloat = 44

    var body: some View {
        let g = Geometry(layout: layout, state: state, unit: unit, showReader: showReader)
        ZStack(alignment: .topLeading) {
            // Sombras por baixo das duas metades, para não marcar a emenda.
            caseShadow(g, x: g.leftX)
            caseShadow(g, x: g.rightX)

            if showReader {
                ReaderView(state: state, width: g.readerWidth, height: g.caseHeight, scale: g.s)
                    .rotationEffect(.degrees(state.reader == .loose ? -2 : 0))
                    .opacity(state.reader == .absent ? 0 : 1)
                    .offset(x: g.readerX, y: g.caseTop)
            }

            halfCase(g, x: g.leftX, left: true)
            halfCase(g, x: g.rightX, left: false)

            // Contatos pogo na lateral, à vista quando o e-reader não está encaixado.
            VStack(spacing: 7 * g.s) {
                ForEach(0..<4, id: \.self) { _ in
                    UnevenRoundedRectangle(bottomTrailingRadius: 1, topTrailingRadius: 1)
                        .fill(Hardware.pogo)
                        .frame(width: 2 * g.s, height: 7 * g.s)
                }
            }
            .opacity(state.reader == .docked ? 0 : 1)
            .offset(x: g.leftX, y: g.caseTop + g.caseHeight / 2 - 26 * g.s)

            // Colunas móveis: o trenó e a saia que tampa o vão quando a coluna sobe.
            ForEach(layout.columns, id: \.index) { column in
                let lift = g.lift(column)
                let x = g.x(column.x, half: column.half)
                ZStack(alignment: .top) {
                    UnevenRoundedRectangle(topLeadingRadius: 6 * g.s, topTrailingRadius: 6 * g.s)
                        .fill(Hardware.caseColor)
                        .frame(width: column.w.cg * unit, height: g.pad + layout.columnsBottom.cg * unit)
                    Rectangle()
                        .fill(Hardware.skirt)
                        .frame(width: column.w.cg * unit, height: lift)
                        .offset(y: g.pad + layout.columnsBottom.cg * unit)
                }
                .overlay(alignment: .trailing) {
                    Rectangle().fill(.black.opacity(lift > 0.5 ? 0.35 : 0)).frame(width: 1)
                }
                .offset(x: x, y: g.caseTop - lift)
            }

            ForEach(layout.keys, id: \.id) { key in
                KeyCap(key: key, unit: unit, glow: glows[key.id], fill: fills?[key.id],
                       selected: selectedKey == key.id, activeHost: state.activeHost) {
                    onKey(key)
                }
                .offset(x: g.x(key.x, half: key.half) + 2 * g.s,
                        y: g.y + key.y.cg * unit + 2 * g.s - g.lift(of: key))
            }

            // Botão que solta as colunas.
            Button(action: onRelease) {
                Capsule()
                    .fill(Color(white: 0.36))
                    .frame(width: 20 * g.s, height: 8 * g.s)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Soltar as colunas (stagger)")
            .offset(x: g.x(5.3, half: .left), y: g.y + 1.125 * unit - 4 * g.s)
        }
        .frame(width: g.width, height: g.height, alignment: .topLeading)
    }

    private func caseShadow(_ g: Geometry, x: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 12 * g.s)
            .fill(Hardware.caseColor)
            .frame(width: g.halfWidth, height: g.caseHeight)
            .shadow(color: .black.opacity(0.28), radius: 18 * g.s, y: 14 * g.s)
            .offset(x: x, y: g.caseTop)
    }

    private func halfCase(_ g: Geometry, x: CGFloat, left: Bool) -> some View {
        let outer = 12 * g.s
        let inner = state.halvesJoined ? 0 : outer
        return UnevenRoundedRectangle(
            topLeadingRadius: left ? outer : inner,
            bottomLeadingRadius: left ? outer : inner,
            bottomTrailingRadius: left ? inner : outer,
            topTrailingRadius: left ? inner : outer
        )
        .fill(Hardware.caseColor)
        .overlay(alignment: .top) {
            Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
        }
        .frame(width: g.halfWidth, height: g.caseHeight)
        .offset(x: x, y: g.caseTop)
    }
}

/// Onde cada peça fica. Mesmas contas do design (canvas "Componente · teclado").
struct Geometry {
    let layout: KeyboardLayout
    let state: KeyboardState
    let unit: CGFloat
    let showReader: Bool

    var s: CGFloat { unit / 44 }
    var pad: CGFloat { 5 * s }
    var width: CGFloat { 980 * s }
    var height: CGFloat { 380 * s }
    /// Topo das teclas (deixa espaço para as colunas subirem).
    var y: CGFloat { 58 * s }
    var caseTop: CGFloat { y - pad }
    var halfWidth: CGFloat { 7 * unit + pad }
    var caseHeight: CGFloat { 6.25 * unit + 2 * pad }
    var readerWidth: CGFloat { 168 * s }

    private var reader: ReaderState { showReader ? state.reader : .absent }
    private var readerSpace: CGFloat {
        switch reader {
        case .absent: 0
        case .docked: readerWidth + 2 * s
        case .loose: readerWidth + 44 * s
        }
    }
    private var splitGap: CGFloat { state.halvesJoined ? 0 : 64 * s }
    private var startX: CGFloat { ((width - (readerSpace + 2 * halfWidth + splitGap)) / 2).rounded() }

    var leftX: CGFloat { startX + readerSpace }
    var rightX: CGFloat { leftX + halfWidth + splitGap }
    var readerX: CGFloat { reader == .absent ? leftX - readerWidth - 70 * s : startX }

    /// x em pontos de uma coordenada do layout, na metade certa.
    func x(_ ux: Float, half: Half) -> CGFloat {
        switch half {
        case .left: leftX + (ux - 4).cg * unit + pad
        case .right: rightX + (ux - 12).cg * unit
        }
    }

    func lift(_ column: ColumnDef) -> CGFloat {
        columnLift(column: column, staggerPercent: state.staggerPercent).cg * unit
    }

    func lift(of key: KeyDef) -> CGFloat {
        guard let c = key.column else { return 0 }
        return lift(layout.columns[Int(c)])
    }
}

extension Float {
    var cg: CGFloat { CGFloat(self) }
}

/// Uma tecla com a luz de fundo passando pela legenda.
struct KeyCap: View {
    let key: KeyDef
    let unit: CGFloat
    let glow: KeyGlow?
    let fill: KeyFill?
    let selected: Bool
    /// Computador ativo: acende a perninha dele na marca da tecla Yggi.
    var activeHost: UInt8? = nil
    let action: () -> Void

    var body: some View {
        let s = unit / 44
        let w = key.w.cg * unit - 4 * s
        let h = key.h.cg * unit - 4 * s
        let shape = RoundedRectangle(cornerRadius: 7 * s)
        Button(action: action) {
            ZStack {
                shape.fill(background)
                    .shadow(color: .black.opacity(0.55), radius: 0, y: 1 * s)
                legends(color: legendColor, s: s)
                if let glow {
                    let lit = Color(glow.color)
                    ZStack {
                        shape.stroke(lit, lineWidth: 1.5 * s)
                            .shadow(color: lit.opacity(0.75), radius: 7 * s)
                        legends(color: glow.color.legendColor, s: s)
                            .shadow(color: lit.opacity(0.75), radius: 3 * s)
                    }
                    .opacity(Double(glow.intensity))
                }
                if selected {
                    shape.stroke(Color.accentColor, lineWidth: 2 * s)
                        .padding(-2 * s)
                }
            }
            .frame(width: w, height: h)
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(key.name)
    }

    private var background: Color {
        if let fill { return fill.background }
        switch key.kind {
        case .yggi: return Hardware.keyYggi
        case .modifier, .function: return Hardware.keyModifier
        case .alpha: return Hardware.keyAlpha
        }
    }

    private var legendColor: Color {
        if let fill { return fill.legend }
        return key.kind == .yggi ? .white : Hardware.legend
    }

    private var small: Bool {
        key.kind == .modifier || key.kind == .function || key.label.count > 3
    }

    @ViewBuilder private func legends(color: Color, s: CGFloat) -> some View {
        if key.kind == .yggi && fill == nil {
            YggiKeyLegend(activeHost: activeHost)
                .frame(width: key.w.cg * unit * 0.55)
        } else {
            textLegends(color: color, s: s)
        }
    }

    private func textLegends(color: Color, s: CGFloat) -> some View {
        VStack(spacing: 1 * s) {
            if !key.sub.isEmpty {
                Text(key.sub).font(.system(size: 10 * s)).opacity(0.7)
            }
            Text(key.label)
                .font(.system(size: (key.h < 1 || small ? 10 : 14) * s,
                              weight: key.kind == .yggi ? .semibold : (small ? .medium : .regular)))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
        .padding(.horizontal, 3 * s)
        .foregroundStyle(color)
    }
}

/// A legenda da tecla Yggi: a marca, com a perninha do computador ativo acesa em branco (é o
/// LED do computador) e as outras apagadas. Tocar a tecla passa para o próximo (até 3).
struct YggiKeyLegend: View {
    let activeHost: UInt8?

    var body: some View {
        let mark = yggiMark()
        let lit = yggiKeyLitLegs(activeHost: activeHost)
        ZStack {
            ForEach(Array(mark.capsules.enumerated()), id: \.offset) { i, capsule in
                let on = lit[i]
                MarkShape(drawing: MarkDrawing(width: mark.width, height: mark.height, capsules: [capsule], dimmed: false))
                    .fill(on ? Color.white : Color.white.opacity(0.28))
                    .shadow(color: on ? .white.opacity(0.9) : .clear, radius: 3)
            }
        }
        .aspectRatio(CGFloat(mark.width / mark.height), contentMode: .fit)
        .animation(.easeInOut(duration: 0.2), value: activeHost)
        .accessibilityLabel(activeHost.map { "computador \($0 + 1)" } ?? "sem computador")
    }
}

/// O teclado com as luzes animadas (efeitos, cores por tecla e teclas de ação).
struct LiveKeyboard: View {
    @Environment(KeyboardStore.self) private var store
    var fills: [String: KeyFill]? = nil
    var selectedKey: String? = nil
    var showReader = true
    var lightsOn = true
    var unit: CGFloat = 44
    var onKey: (KeyDef) -> Void = { _ in }

    var body: some View {
        TimelineView(.animation(paused: !lightsOn)) { _ in
            let glows = lightsOn
                ? Dictionary(store.engine.frame(state: store.state, fnHeld: store.fnHeld, time: store.now).map { ($0.keyId, $0) },
                             uniquingKeysWith: { a, _ in a })
                : [:]
            KeyboardView(layout: store.layout, state: store.state, glows: glows, fills: fills,
                         selectedKey: selectedKey, showReader: showReader,
                         onKey: { key in
                             store.pressKey(key.id)
                             onKey(key)
                         },
                         onRelease: { store.setStagger(true) },
                         unit: unit)
        }
    }
}
