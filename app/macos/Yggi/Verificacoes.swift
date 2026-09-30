#if DEBUG
import AppKit
import SwiftUI
import YggiCore

/// `Yggi.app/Contents/MacOS/Yggi --verificar` confere as regras da camada Swift e sai com erro
/// se alguma falhar (`make test` roda isto depois dos testes do núcleo).
///
/// A lógica do teclado é testada no núcleo, em Rust. Aqui ficam as regras da cola com o macOS,
/// cada uma nascida de uma regressão que já aconteceu:
/// - o ícone da barra parou de mudar (o `AppDelegate` não era achado);
/// - a janela cortava a barra lateral e a biblioteca (tela mais larga que a janela);
/// - a janela ficava sempre por cima / em outra mesa, e o app não aparecia no Dock;
/// - o Dock mostrava o ícone velho (ícone fora do pacote);
/// - um widget num tamanho novo poderia travar ao desenhar.
@MainActor
enum Verificacoes {
    private static var falhas: [String] = []

    static func runIfRequested() {
        guard CommandLine.arguments.contains("--verificar") else { return }
        verificar("AppDelegate.shared aponta para o delegate do app") { appDelegateIsReachable() }
        verificar("o ícone da barra segue o teclado (stagger e metades)") { menuBarIconFollowsState() }
        verificar("os estados do ícone desenham imagens diferentes") { menuBarIconStatesDiffer() }
        verificar("toda seção cabe na janela mínima") { sectionsFitMinimumWindow() }
        verificar("a janela principal é comum (nem sempre por cima, nem em todas as mesas)") { mainWindowIsNormal() }
        verificar("o app é normal: aparece no Dock e tem o ícone no pacote") { appIsRegularWithIcon() }
        verificar("todo widget desenha em todo tamanho que aceita") { everyWidgetRendersInEverySize() }

        if falhas.isEmpty {
            print("✓ verificações da camada Swift passaram")
            exit(0)
        }
        print("✗ \(falhas.count) verificação(ões) falharam:")
        falhas.forEach { print("  - \($0)") }
        exit(1)
    }

    private static func verificar(_ nome: String, _ check: () -> String?) {
        if let erro = check() {
            falhas.append("\(nome): \(erro)")
            print("✗ \(nome)\n    \(erro)")
        } else {
            print("✓ \(nome)")
        }
    }

    /// Roda o laço principal até `done` ou o tempo acabar (animações e avisos do núcleo).
    private static func waitUntil(_ seconds: Double, _ done: () -> Bool) -> Bool {
        let limit = Date().addingTimeInterval(seconds)
        while !done() && Date() < limit {
            RunLoop.main.run(until: Date().addingTimeInterval(0.02))
        }
        return done()
    }

    // MARK: verificações

    private static func appDelegateIsReachable() -> String? {
        let delegate = AppDelegate()
        return AppDelegate.shared === delegate ? nil : "AppDelegate.shared não é o delegate criado (o SwiftUI usa outro objeto em NSApp.delegate)"
    }

    private static func menuBarIconFollowsState() -> String? {
        let store = KeyboardStore.simulated(.normal, animated: false)
        var drawn = 0
        let icon = MenuBarIcon(store: store) { _, _ in drawn += 1 }
        store.simulator?.setStagger(percent: 0)
        store.simulator?.setHalvesJoined(joined: true)
        _ = waitUntil(1) { !icon.isAnimating && icon.shown?.stagger == 0 }
        let before = drawn
        store.simulator?.setStagger(percent: 100)
        store.simulator?.setHalvesJoined(joined: false)
        let arrived = waitUntil(3) { !icon.isAnimating && icon.shown.map { $0 == (100, 1) } == true }
        guard arrived else { return "ficou em \(String(describing: icon.shown)), esperado (100, 1)" }
        return drawn > before + 2 ? nil : "desenhou \(drawn - before) quadros; a animação não rodou"
    }

    private static func menuBarIconStatesDiffer() -> String? {
        func png(_ stagger: Float, _ separation: Float) -> Data? {
            MarkRenderer.menuBarImage(keyboardGlyphFrame(stagger: stagger, separation: separation)).tiffRepresentation
        }
        let images = [png(0, 0), png(100, 0), png(0, 1), png(100, 1)]
        return Set(images.compactMap { $0 }).count == 4 ? nil : "dois estados desenham o mesmo ícone"
    }

    private static func sectionsFitMinimumWindow() -> String? {
        let store = KeyboardStore.simulated(.normal, animated: false)
        let minimum = MainView.minimumSize
        var problems: [String] = []
        for section in [AppSection.overview, .keys, .lights, .stats, .menuBar] {
            store.section = section
            let host = NSHostingController(rootView: MainView().environment(store))
            host.view.frame = CGRect(origin: .zero, size: minimum)
            host.view.layoutSubtreeIfNeeded()
            let needed = host.view.fittingSize
            if needed.width > minimum.width + 1 {
                problems.append("\(section.title) pede \(Int(needed.width)) de largura (mínimo da janela \(Int(minimum.width)))")
            }
        }
        return problems.isEmpty ? nil : problems.joined(separator: "; ")
    }

    private static func mainWindowIsNormal() -> String? {
        let window = AppDelegate.makeMainWindow(store: KeyboardStore.simulated(.normal, animated: false))
        var problems: [String] = []
        if window.level != .normal { problems.append("nível \(window.level.rawValue), esperado normal") }
        for flag: NSWindow.CollectionBehavior in [.canJoinAllSpaces, .fullScreenAuxiliary, .moveToActiveSpace, .stationary] where window.collectionBehavior.contains(flag) {
            problems.append("collectionBehavior tem \(flag.rawValue)")
        }
        if window.contentMinSize.width > 0, window.contentMinSize.width + 1 < MainView.minimumSize.width {
            problems.append("mínimo \(window.contentMinSize.width) menor que o das telas")
        }
        return problems.isEmpty ? nil : problems.joined(separator: "; ")
    }

    private static func appIsRegularWithIcon() -> String? {
        let info = Bundle.main.infoDictionary ?? [:]
        if (info["LSUIElement"] as? Bool) == true || (info["LSUIElement"] as? String) == "YES" || (info["LSUIElement"] as? String) == "1" {
            return "LSUIElement está ligado: o app some do Dock e do Cmd+Tab"
        }
        guard (info["CFBundleIconName"] as? String) == "AppIcon" else { return "CFBundleIconName não é AppIcon" }
        guard Bundle.main.url(forResource: "AppIcon", withExtension: "icns") != nil else { return "AppIcon.icns não está no pacote" }
        return nil
    }

    private static func everyWidgetRendersInEverySize() -> String? {
        let store = KeyboardStore.simulated(.normal, animated: false)
        let metrics = GridMetrics.popover
        var failed: [String] = []
        for info in store.catalog {
            for size in info.sizes {
                for scheme in [ColorScheme.light, .dark] {
                    let rect = metrics.rect(WidgetPlacement(widgetId: 0, column: 0, row: 0, columns: UInt8(size.columns), rows: UInt8(size.rows)))
                    let view = WidgetView(slot: WidgetSlot(id: 0, kind: info.kind, size: size, showTitle: true, column: 0, row: 0))
                        .frame(width: rect.width, height: rect.height)
                        .environment(store)
                        .environment(\.colorScheme, scheme)
                    if ImageRenderer(content: view).cgImage == nil { failed.append("\(info.name) \(size.label)") }
                }
            }
        }
        return failed.isEmpty ? nil : "não desenharam: " + failed.joined(separator: ", ")
    }
}
#endif
