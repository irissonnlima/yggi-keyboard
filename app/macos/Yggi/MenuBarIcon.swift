import AppKit
import Observation
import YggiCore

/// O ícone da barra de menus seguindo o teclado: observa o `KeyboardStore` e, a cada mudança,
/// anima o teclado em miniatura do quadro mostrado até o estado novo.
///
/// Fica separado do `AppDelegate` para poder ser verificado sem barra de menus (`--verificar`):
/// quem desenha é o `render`, que no app põe a imagem no botão do ícone.
@MainActor
final class MenuBarIcon {
    /// O quadro na tela agora: abertura do stagger (0 a 100) e separação das metades (0 a 1).
    private(set) var shown: (stagger: Double, separation: Double)?
    private(set) var dimmed = false

    private let store: KeyboardStore
    private let render: (NSImage, String) -> Void
    private var animation: (from: (Double, Double), to: (Double, Double), start: Date, duration: Double, opening: Bool)?
    private var timer: Timer?

    init(store: KeyboardStore, render: @escaping (_ image: NSImage, _ description: String) -> Void) {
        self.store = store
        self.render = render
        watch()
    }

    /// Para onde o ícone está indo (o estado atual do teclado).
    var target: (stagger: Double, separation: Double) {
        (Double(store.state.staggerPercent), store.state.halvesJoined ? 0 : 1)
    }

    var isAnimating: Bool { animation != nil }

    /// Observa o estado; o `onChange` do Observation dispara uma vez, então se observa de novo.
    private func watch() {
        withObservationTracking {
            update(store.state)
        } onChange: { [weak self] in
            Task { @MainActor in self?.watch() }
        }
    }

    private func update(_ state: KeyboardState) {
        dimmed = !state.isConnected
        let target = (Double(state.staggerPercent), state.halvesJoined ? 0.0 : 1.0)
        guard let current = shown, current != target else {
            shown = target
            draw()
            return
        }
        // Abrir é a mola soltando as colunas (mais lento, freia no fim); fechar é empurrar até a trava.
        let opening = target.0 > current.stagger || target.1 > current.separation
        animation = (from: (current.stagger, current.separation), to: target, start: Date(), duration: opening ? 0.55 : 0.35, opening: opening)
        if timer == nil {
            let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.step() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }
    }

    private func step() {
        guard let a = animation else { stop(); return }
        let t = min(Date().timeIntervalSince(a.start) / a.duration, 1)
        let k = a.opening ? 1 - pow(1 - t, 3) : t * t * t
        shown = (a.from.0 + (a.to.0 - a.from.0) * k, a.from.1 + (a.to.1 - a.from.1) * k)
        draw()
        if t >= 1 { stop() }
    }

    private func stop() {
        animation = nil
        timer?.invalidate()
        timer = nil
    }

    private func draw() {
        guard let shown else { return }
        var drawing = keyboardGlyphFrame(stagger: Float(shown.stagger), separation: Float(shown.separation))
        drawing.dimmed = dimmed
        render(MarkRenderer.menuBarImage(drawing), Self.description(store.state))
    }

    static func description(_ state: KeyboardState) -> String {
        guard state.isConnected else { return "Yggi, \(state.connectionText.lowercased())" }
        var parts = ["Yggi"]
        parts.append(state.staggerPercent > 0 ? "stagger aberto \(state.staggerPercent)%" : "ortho")
        parts.append(state.halvesJoined ? "metades juntas" : "metades separadas")
        return parts.joined(separator: ", ")
    }
}
