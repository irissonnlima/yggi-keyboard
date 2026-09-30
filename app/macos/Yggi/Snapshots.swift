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
        let poses: [(String, MarkPose)] = [
            ("Ortho, metades juntas", MarkPose(open: false, separated: false, outline: false, lowBattery: false)),
            ("Stagger aberto", MarkPose(open: true, separated: false, outline: false, lowBattery: false)),
            ("Metades separadas", MarkPose(open: false, separated: true, outline: false, lowBattery: false)),
            ("Aberto e separado", MarkPose(open: true, separated: true, outline: false, lowBattery: false)),
            ("Bateria baixa", MarkPose(open: false, separated: false, outline: false, lowBattery: true)),
            ("Aberto, bateria baixa", MarkPose(open: true, separated: false, outline: false, lowBattery: true)),
            ("Separado, bateria baixa", MarkPose(open: false, separated: true, outline: false, lowBattery: true)),
            ("Desconectado", MarkPose(open: false, separated: false, outline: true, lowBattery: false)),
        ]
        let icons = VStack(alignment: .leading, spacing: 10) {
            ForEach(poses, id: \.0) { name, pose in
                HStack(spacing: 18) {
                    Text(name).font(.system(size: 13)).frame(width: 170, alignment: .leading)
                    ForEach([false, true], id: \.self) { dark in
                        HStack(spacing: 14) {
                            Image(systemName: "wifi").font(.system(size: 13))
                            Image(nsImage: MarkRenderer.menuBarImage(pose: pose))
                                .renderingMode(.template)
                            Image(systemName: "battery.75percent").font(.system(size: 13))
                        }
                        .foregroundStyle(dark ? Color.white : Color.black)
                        .padding(.horizontal, 12)
                        .frame(height: 24)
                        .background(dark ? Color(white: 0.16) : Color(white: 0.93))
                    }
                    YggiMark(pose: pose, line: 7).fill(Color(white: 0.15)).frame(width: 54, height: 50)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .environment(\.colorScheme, .light)
        save(icons, to: dir.appending(path: "icone-barra.png"))

        // Telas (sem a barra de ferramentas, que é da janela).
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "-escuro" : ""
            let s = KeyboardStore.simulated(.normal, animated: false)
            s.simulator?.setCapsLock(on: true)
            save(screen(OverviewScreen(), s, scheme), to: dir.appending(path: "visao-geral\(suffix).png"))
            save(screen(LightsScreen(), s, scheme), to: dir.appending(path: "luzes\(suffix).png"))
            save(screen(StatsScreen(scrolls: false), s, scheme), to: dir.appending(path: "estatisticas\(suffix).png"))
            // Cada aba de fábrica e uma aba com todos os widgets, no maior tamanho de cada um.
            var all = s.menuBar.tabs
            let every = s.catalog.enumerated().map { i, info in
                WidgetSlot(id: UInt32(1000 + i), kind: info.kind,
                           size: info.sizes.max { $0.columns * $0.rows < $1.columns * $1.rows } ?? info.sizes[0], showTitle: true)
            }
            all.append(MenuTab(id: 999, name: "Todos", widgets: every))
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
