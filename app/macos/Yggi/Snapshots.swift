#if DEBUG
import AppKit
import SwiftUI
import YggiCore

/// `Yggi.app/Contents/MacOS/Yggi --snapshots <pasta>` desenha telas e estados do teclado em PNG
/// e sai. Serve para conferir a interface. (Controles nativos, como seletores, aparecem como
/// caixas amarelas: o gerador de imagens do SwiftUI não os desenha.)
enum Snapshots {
    @MainActor
    static func runIfRequested() {
        let args = CommandLine.arguments
        guard let flag = args.firstIndex(of: "--snapshots") else { return }
        let dir = URL(fileURLWithPath: args.indices.contains(flag + 1) ? args[flag + 1] : "snapshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Estados do teclado.
        let store = KeyboardStore.simulated(.normal, animated: false)
        store.simulator?.setCapsLock(on: true)
        store.simulator?.setStagger(percent: 0)
        let states: [(String, (Simulator) -> Void)] = [
            ("teclado-ortho", { _ in }),
            ("teclado-stagger", { $0.setStagger(percent: 100) }),
            ("teclado-separado-solto", { $0.setHalvesJoined(joined: false); $0.setReader(reader: .loose) }),
            ("teclado-sem-ereader", { $0.setHalvesJoined(joined: true); $0.setReader(reader: .absent); $0.setStagger(percent: 60) }),
        ]
        for (name, change) in states {
            if let sim = store.simulator { change(sim) }
            let state = store.simulator.map { KeyboardSession.simulated(simulator: $0).state() } ?? store.state
            let glows = Dictionary(store.engine.frame(state: state, fnHeld: false, time: 0.4).map { ($0.keyId, $0) },
                                   uniquingKeysWith: { a, _ in a })
            let view = KeyboardView(layout: store.layout, state: state, glows: glows)
                .padding(10)
                .background(Color(white: 0.96))
            save(view, to: dir.appending(path: "\(name).png"))
        }

        // Ícone da barra de menus em cada estado: tamanho real nas barras clara e escura, e ampliado.
        let cases: [(String, UInt8, Bool, Bool)] = [
            ("Ortho, metades juntas", 0, true, true),
            ("Abrindo (50%)", 50, true, true),
            ("Stagger aberto (100%)", 100, true, true),
            ("Ortho, metades separadas", 0, false, true),
            ("Aberto e separado", 100, false, true),
            ("Desconectado", 0, true, false),
        ]
        let icons = VStack(alignment: .leading, spacing: 10) {
            ForEach(cases, id: \.0) { name, percent, joined, connected in
                let drawing = { () -> MarkDrawing in
                    var d = keyboardGlyph(staggerPercent: percent, halvesJoined: joined)
                    d.dimmed = !connected
                    return d
                }()
                HStack(spacing: 18) {
                    Text(name).font(.system(size: 13)).frame(width: 170, alignment: .leading)
                    ForEach([false, true], id: \.self) { dark in
                        HStack(spacing: 14) {
                            Image(systemName: "wifi").font(.system(size: 13))
                            Image(nsImage: MarkRenderer.menuBarImage(drawing))
                                .renderingMode(.template)
                            Image(systemName: "battery.75percent").font(.system(size: 13))
                        }
                        .foregroundStyle(dark ? Color.white : Color.black)
                        .padding(.horizontal, 12)
                        .frame(height: 24)
                        .background(dark ? Color(white: 0.16) : Color(white: 0.93))
                    }
                    KeyboardGlyph(percent: percent, joined: joined).foregroundStyle(Color(white: 0.15).opacity(connected ? 1 : 0.35)).frame(width: 120, height: 40)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .environment(\.colorScheme, .light)
        save(icons, to: dir.appending(path: "icone-barra.png"))

        // Cada widget em cada tamanho que ele aceita (deitado, em pé, pequeno e grande).
        for scheme in [ColorScheme.dark, .light] {
            let g = KeyboardStore.simulated(.normal, animated: false)
            g.simulator?.setStagger(percent: 60)
            let metrics = GridMetrics.popover
            let gallery = VStack(alignment: .leading, spacing: 18) {
                ForEach(g.catalog, id: \.kind) { info in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(info.name).font(.headline)
                        HStack(alignment: .top, spacing: 10) {
                            ForEach(info.sizes, id: \.self) { size in
                                let r = metrics.rect(WidgetPlacement(widgetId: 0, column: 0, row: 0,
                                                                     columns: UInt8(size.columns), rows: UInt8(size.rows)))
                                VStack(spacing: 3) {
                                    WidgetView(slot: WidgetSlot(id: 0, kind: info.kind, size: size, showTitle: true, column: 0, row: 0))
                                        .frame(width: r.width, height: r.height)
                                    Text(size.label).font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
            .environment(g)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, scheme)
            save(gallery, to: dir.appending(path: "widgets-tamanhos\(scheme == .dark ? "-escuro" : "").png"))
        }

        // Mapa de calor do widget na forma do teclado, nos quatro estados.
        let counts = store.statistics(.today)?.keyCounts ?? []
        let top = counts.map(\.count).max() ?? 0
        let levels = Dictionary(counts.map { ($0.keyId, Int(heatLevel(count: $0.count, max: top))) }, uniquingKeysWith: { a, _ in a })
        let heat = VStack(alignment: .leading, spacing: 14) {
            ForEach([(0.0, 0.0, "Ortho, juntas"), (100, 0, "Aberto, juntas"), (0, 1, "Ortho, separadas"), (100, 1, "Aberto, separadas")], id: \.2) { st, sep, name in
                HStack(spacing: 16) {
                    Text(name).font(.system(size: 13)).frame(width: 130, alignment: .leading)
                    HeatKeyboard(layout: store.layout, levels: levels, stagger: st, separation: sep)
                        .frame(width: 330, height: 150)
                        .background(Color(white: 0.17))
                }
            }
        }
        .padding(20)
        .background(Color(white: 0.12))
        .environment(\.colorScheme, .dark)
        save(heat, to: dir.appending(path: "mapa-de-calor.png"))

        // Telas (sem a barra de ferramentas, que é da janela).
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "-escuro" : ""
            let s = KeyboardStore.simulated(.normal, animated: false)
            s.simulator?.setCapsLock(on: true)
            save(screen(OverviewScreen(), s, scheme), to: dir.appending(path: "visao-geral\(suffix).png"))
            save(screen(LightsScreen(), s, scheme), to: dir.appending(path: "luzes\(suffix).png"))
            save(screen(StatsScreen(scrolls: false), s, scheme), to: dir.appending(path: "estatisticas\(suffix).png"))
            // Cada aba de fábrica e uma aba com todos os widgets, no maior tamanho de cada um.
            // Montada pelo núcleo, como o editor faria: adiciona cada widget e aumenta até o maior tamanho.
            var config = menuAddTab(config: defaultMenuBar(), name: "Todos")
            let todos = config.tabs.last!.id
            for info in s.catalog {
                let id = config.nextId
                config = menuAddWidget(config: config, tabId: todos, kind: info.kind, at: nil, size: nil)
                let biggest = info.sizes.max { $0.columns * $0.rows < $1.columns * $1.rows } ?? info.sizes[0]
                config = menuSetWidgetSize(config: config, widgetId: id, size: biggest)
            }
            let all = config.tabs
            let tabs = HStack(alignment: .top, spacing: 20) {
                ForEach(all, id: \.id) { tab in
                    VStack(alignment: .leading) {
                        Text(tab.name).font(.headline)
                        WidgetGrid(tab: tab) { slot, _ in WidgetView(slot: slot) }
                    }
                }
            }
            .padding(20)
            .environment(s)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, scheme)
            save(tabs, to: dir.appending(path: "abas\(suffix).png"))
            save(MenuBarView().environment(s).environment(\.colorScheme, scheme)
                    .background(Color(nsColor: .windowBackgroundColor)),
                 to: dir.appending(path: "menu\(suffix).png"))
        }
        exit(0)
    }

    @MainActor
    private static func screen(_ view: some View, _ store: KeyboardStore, _ scheme: ColorScheme) -> some View {
        view
            .environment(store)
            .frame(width: 1048, height: 780)
            .background(Color(nsColor: .windowBackgroundColor))
            .environment(\.colorScheme, scheme)
    }

    @MainActor
    private static func save(_ view: some View, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let image = renderer.cgImage else { return }
        let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
        try? png?.write(to: url)
    }
}
#endif
