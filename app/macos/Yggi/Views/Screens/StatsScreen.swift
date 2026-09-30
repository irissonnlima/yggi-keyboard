import Charts
import SwiftUI
import YggiCore

/// Estatísticas de digitação: só contagens, nunca o texto.
struct StatsScreen: View {
    @Environment(KeyboardStore.self) private var store
    @State private var period: StatsPeriod = .today
    @State private var hovered: String?
    /// Falso só nas imagens de conferência (o gerador de imagens não desenha rolagem).
    var scrolls = true

    var body: some View {
        let stats = store.statistics(period)
        Group {
            if scrolls {
                ScrollView { content(stats) }
            } else {
                content(stats)
            }
        }
        .navigationTitle("Estatísticas")
        .navigationSubtitle("Contadas no teclado. O texto nunca é guardado, só contagens.")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if stats?.simulated == true {
                    Text("dados simulados")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.orange)
                }
                Picker("Período", selection: $period) {
                    Text("Hoje").tag(StatsPeriod.today)
                    Text("Semana").tag(StatsPeriod.week)
                    Text("Mês").tag(StatsPeriod.month)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder
    private func content(_ stats: Statistics?) -> some View {
        if let stats {
            VStack(spacing: 12) {
                tiles(stats)
                heatmap(stats)
                HStack(alignment: .top, spacing: 12) {
                    speedChart(stats).frame(maxWidth: .infinity)
                    sidePanel(stats).frame(width: 320)
                }
            }
            .padding(20)
        } else {
            ContentUnavailableView("Sem estatísticas", systemImage: "chart.bar",
                                   description: Text("Conecte o teclado para ver as estatísticas."))
        }
    }

    // MARK: resumo

    private func tiles(_ s: Statistics) -> some View {
        let t = s.totals
        let previous = switch period {
        case .today: "ontem"
        case .week: "a semana anterior"
        case .month: "o mês anterior"
        }
        return Grid(horizontalSpacing: 12) {
            GridRow {
                tile("Teclas digitadas", t.keystrokes.formatted(), "", "\(t.changePercent >= 0 ? "+" : "")\(t.changePercent)% que \(previous)")
                tile("Palavras", t.words.formatted(), "", "≈ \((Double(t.keystrokes) / Double(max(t.words, 1))).formatted(.number.precision(.fractionLength(1)))) teclas por palavra")
                tile("Velocidade média", "\(t.avgWpm)", "ppm", "enquanto digita")
                tile("Pico", "\(t.peakWpm)", "ppm", t.peakWhen)
                tile("Tempo digitando", "\(t.typingMinutes / 60)h \(t.typingMinutes % 60)", "min", "em \(t.sessions) sessões")
            }
        }
    }

    private func tile(_ title: String, _ value: String, _ unit: String, _ note: String) -> some View {
        Card(padding: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value).font(.system(size: 24, weight: .semibold)).monospacedDigit()
                    Text(unit).font(.caption.weight(.medium)).foregroundStyle(.secondary)
                }
                Text(note).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
        }
    }

    // MARK: mapa de calor

    private static let ramp: [(Color, Color)] = [
        (Color(red: 0.863, green: 0.910, blue: 0.973), Hardware.legend),
        (Color(red: 0.702, green: 0.804, blue: 0.945), Hardware.legend),
        (Color(red: 0.494, green: 0.667, blue: 0.902), Color(white: 0.09)),
        (Color(red: 0.247, green: 0.498, blue: 0.839), .white),
        (Color(red: 0.114, green: 0.337, blue: 0.659), .white),
    ]

    private func heatmap(_ s: Statistics) -> some View {
        let max = s.keyCounts.map(\.count).max() ?? 0
        var fills: [String: KeyFill] = [:]
        for k in s.keyCounts {
            let level = Int(heatLevel(count: k.count, max: max))
            fills[k.keyId] = KeyFill(background: Self.ramp[level].0, legend: Self.ramp[level].1)
        }
        let total = max > 0 ? s.keyCounts.reduce(0) { $0 + $1.count } : 1
        let top = topKeys(stats: s, n: 8)
        let first = top.first?.count ?? 1
        let unit: CGFloat = 36

        return Card {
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text("Teclas mais usadas").font(.headline)
                        Spacer()
                        Text("menos").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 2) {
                            ForEach(0..<5, id: \.self) { i in
                                RoundedRectangle(cornerRadius: 2).fill(Self.ramp[i].0).frame(width: 16, height: 10)
                            }
                        }
                        Text("mais").font(.caption).foregroundStyle(.secondary)
                    }
                    CroppedKeyboard(unit: unit) {
                        KeyboardView(layout: store.layout, state: heatState, fills: fills, showReader: false, unit: unit)
                    }
                }
                .fixedSize()

                VStack(alignment: .leading, spacing: 9) {
                    Text("Ranking").font(.headline)
                    ForEach(top, id: \.keyId) { k in
                        HStack(spacing: 10) {
                            Text(keyLabel(k.keyId)).font(.callout).lineLimit(1).frame(width: 110, alignment: .leading)
                            GeometryReader { geo in
                                UnevenRoundedRectangle(bottomTrailingRadius: 4, topTrailingRadius: 4)
                                    .fill(Series.one)
                                    .frame(width: geo.size.width * CGFloat(k.count) / CGFloat(first))
                            }
                            .frame(height: 8)
                            Text((Double(k.count) / Double(total)).formatted(.percent.precision(.fractionLength(1))))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 48, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    /// O mapa de calor mostra o teclado em ortho, metades juntas, sem luzes.
    private var heatState: KeyboardState {
        var s = store.state
        s.staggerPercent = 0
        s.halvesJoined = true
        s.activeHost = nil
        return s
    }

    private func keyLabel(_ id: String) -> String {
        store.layout.keys.first { $0.id == id }?.name ?? id
    }

    // MARK: velocidade

    private func speedChart(_ s: Statistics) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Velocidade " + (period == .today ? "por hora" : (period == .week ? "por dia" : "por semana")))
                        .font(.headline)
                    Spacer()
                    Text("palavras por minuto").font(.caption).foregroundStyle(.secondary)
                }
                Chart(s.speed, id: \.label) { point in
                    BarMark(x: .value("Quando", point.label), y: .value("ppm", point.wpm), width: .ratio(0.7))
                        .foregroundStyle(Series.one)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 4, topTrailingRadius: 4))
                        .opacity(hovered == nil || hovered == point.label ? 1 : 0.45)
                        .annotation(position: .top) {
                            if hovered == point.label {
                                Text("\(point.label) · \(point.wpm) ppm")
                                    .font(.caption.weight(.medium))
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(RoundedRectangle(cornerRadius: 6).fill(.primary))
                                    .foregroundStyle(Color(nsColor: .windowBackgroundColor))
                            }
                        }
                }
                .chartXSelection(value: $hovered)
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 30, 60, 90]) { _ in
                        AxisGridLine().foregroundStyle(.quaternary)
                        AxisValueLabel()
                    }
                }
                .frame(height: 200)
            }
        }
    }

    // MARK: computadores e modos

    private func sidePanel(_ s: Statistics) -> some View {
        let names = store.state.hosts.map { $0.name ?? "Computador \($0.index + 1)" }
        let colors = [Series.one, Series.two, Series.three]
        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Por computador").font(.headline)
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(Array(s.hosts.enumerated()), id: \.offset) { i, h in
                            Rectangle().fill(colors[i % 3])
                                .frame(width: max(0, (geo.size.width - 4) * CGFloat(h.percent) / 100))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .frame(height: 10)
                .accessibilityHidden(true)
                ForEach(Array(s.hosts.enumerated()), id: \.offset) { i, h in
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 3).fill(colors[i % 3]).frame(width: 10, height: 10)
                        Text(names[Int(h.hostIndex)])
                        Spacer()
                        Text("\(h.percent)%").monospacedDigit().foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }
                Divider().padding(.vertical, 2)
                Text("Ortho × stagger").font(.headline)
                HStack(alignment: .top) {
                    mode("Ortho", s.ortho)
                    mode("Stagger 150%", s.stagger)
                }
            }
        }
    }

    private func mode(_ title: String, _ m: ModeStats) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(m.wpm)").font(.title3.weight(.semibold)).monospacedDigit()
                Text("ppm").font(.caption).foregroundStyle(.secondary)
            }
            Text("\((Double(m.correctionsPerMille) / 10).formatted(.number.precision(.fractionLength(1))))% de correções")
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Cores das séries (paleta validada; tons próprios no tema escuro).
enum Series {
    static let one = dynamic(light: 0x2a78d6, dark: 0x3987e5)
    static let two = dynamic(light: 0xeb6834, dark: 0xd95926)
    static let three = dynamic(light: 0x1baf7a, dark: 0x199e70)

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        func ns(_ v: UInt32) -> NSColor {
            NSColor(srgbRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255,
                    blue: CGFloat(v & 255) / 255, alpha: 1)
        }
        return Color(nsColor: NSColor(name: nil) {
            $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? ns(dark) : ns(light)
        })
    }
}

/// Mostra só o corpo do teclado (sem o espaço reservado ao e-reader e às colunas).
struct CroppedKeyboard<Content: View>: View {
    let unit: CGFloat
    @ViewBuilder var content: Content

    var body: some View {
        let s = unit / 44
        let bodyWidth = 14 * unit + 2 * 5 * s
        let bodyHeight = 6.25 * unit + 2 * 5 * s
        let x = ((980 * s - bodyWidth) / 2).rounded()
        let y = 58 * s - 5 * s
        content
            .offset(x: -x + 4, y: -y + 4)
            .frame(width: bodyWidth + 8, height: bodyHeight + 8, alignment: .topLeading)
            .clipped()
    }
}
