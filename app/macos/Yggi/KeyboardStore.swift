import Foundation
import Observation
import SwiftUI
import YggiCore

/// Liga as telas ao núcleo. Toda a lógica do teclado fica no núcleo em Rust;
/// aqui só se guarda o último estado, o rascunho das luzes e se repassam os comandos.
@MainActor @Observable
final class KeyboardStore {
    private(set) var state: KeyboardState
    /// Mensagem do último comando que falhou, já em português (vem do núcleo).
    var lastError: String?
    /// Presente só quando o teclado é simulado.
    let simulator: Simulator?
    /// Layout físico, igual em todas as plataformas.
    let layout = yggiLayout()

    /// Rascunho das luzes editado na tela de Luzes. "Enviar ao teclado" grava no teclado.
    var lighting: LightingConfig {
        didSet { engine.setConfig(config: lighting) }
    }
    private(set) var sentLighting: LightingConfig
    var hasUnsentLighting: Bool { lighting != sentLighting }
    /// Simula segurar fn (a tecla real vem do teclado).
    var fnHeld = false
    /// Quanto de stagger usar ao soltar as colunas.
    var staggerLevel: UInt8 = 150

    /// Calcula a luz de cada tecla, quadro a quadro.
    @ObservationIgnored let engine: LightingEngine
    /// Relógio comum das animações de luz.
    @ObservationIgnored let clockStart = Date()

    @ObservationIgnored private let session: KeyboardSession

    init(session: KeyboardSession, simulator: Simulator? = nil) {
        self.session = session
        self.simulator = simulator
        self.state = session.state()
        let config = (try? session.lighting()) ?? defaultLighting()
        self.lighting = config
        self.sentLighting = config
        self.engine = LightingEngine(config: config)
        // O núcleo avisa de qualquer thread; a fila principal mantém a ordem dos avisos.
        _ = session.subscribe(listener: StateRelay { [weak self] state in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.apply(state) }
            }
        })
    }

    static func simulated(_ scenario: Scenario = .normal, animated: Bool = true) -> KeyboardStore {
        let simulator = Simulator(scenario: scenario, animated: animated)
        return KeyboardStore(session: .simulated(simulator: simulator), simulator: simulator)
    }

    var now: Double { Date().timeIntervalSince(clockStart) }

    /// Aplica o novo estado com a animação que combina com o que mudou.
    private func apply(_ new: KeyboardState) {
        let old = state
        if new.reader == .docked, old.reader != .docked {
            engine.dock(at: now)
        }
        withAnimation(Self.animation(from: old, to: new)) {
            state = new
        }
    }

    private static func animation(from old: KeyboardState, to new: KeyboardState) -> Animation? {
        if new.staggerPercent > old.staggerPercent {
            // A mola puxa as colunas e passa um pouco do ponto.
            return .spring(response: 0.55, dampingFraction: 0.55)
        }
        if new.staggerPercent < old.staggerPercent {
            // Empurradas até o clique da trava.
            return .easeIn(duration: 0.35)
        }
        if new.halvesJoined != old.halvesJoined || new.reader != old.reader {
            return .spring(response: 0.5, dampingFraction: 0.72)
        }
        return .easeInOut(duration: 0.25)
    }

    // MARK: comandos

    func connect() { run { try session.connect() } }
    func disconnect() { run { try session.disconnect() } }
    func selectHost(_ index: UInt8) { run { try session.selectHost(index: index) } }

    func sendLighting() {
        run {
            try session.setLighting(config: lighting)
            sentLighting = lighting
        }
    }

    func discardLighting() { lighting = sentLighting }

    func statistics(_ period: StatsPeriod) -> Statistics? {
        try? session.statistics(period: period)
    }

    func pressKey(_ id: String) {
        engine.press(keyId: id, at: now)
        guard let simulator else { return }
        switch id {
        case "L-yggi": simulator.tapYggiKey()
        case "L-caps": simulator.setCapsLock(on: !state.capsLock)
        default: break
        }
    }

    // Controles físicos (só no simulador; no teclado real vêm dos sensores).
    func setStagger(_ on: Bool) { simulator?.setStagger(percent: on ? staggerLevel : 0) }
    func setStaggerLevel(_ level: UInt8) {
        staggerLevel = level
        simulator?.setStagger(percent: level)
    }
    func setHalvesJoined(_ joined: Bool) { simulator?.setHalvesJoined(joined: joined) }
    func setReader(_ reader: ReaderState) { simulator?.setReader(reader: reader) }
    func replayDock() { engine.dock(at: now) }

    private func run(_ command: () throws -> Void) {
        do {
            try command()
            lastError = nil
        } catch let error as KeyboardError {
            lastError = error.message
        } catch {
            lastError = error.localizedDescription
        }
    }
}

private final class StateRelay: StateListener {
    let handler: @Sendable (KeyboardState) -> Void

    init(_ handler: @escaping @Sendable (KeyboardState) -> Void) {
        self.handler = handler
    }

    func onState(state: KeyboardState) {
        handler(state)
    }
}

extension KeyboardError {
    var message: String {
        switch self {
        case .NotConnected(let message), .InvalidHost(let message), .HostNotPaired(let message):
            message.prefix(1).uppercased() + message.dropFirst()
        }
    }
}

extension KeyboardState {
    var isConnected: Bool {
        if case .connected = connection { true } else { false }
    }

    var activeHostName: String? {
        guard let index = activeHost, let host = hosts.first(where: { $0.index == index }) else { return nil }
        return host.name ?? "Computador \(index + 1)"
    }

    var connectionText: String {
        switch connection {
        case .disconnected: "Desconectado"
        case .connecting: "Conectando…"
        case .connected(.bluetooth): "Bluetooth"
        case .connected(.usb): "USB"
        }
    }
}
