import AppKit
import Observation
import SwiftUI
import YggiCore

/// Ícone na barra de menus, balão com os widgets e janelas do app.
///
/// Feito em AppKit: o `NSStatusItem` com `NSPopover` dá o balão com a setinha apontando para
/// o ícone, e as janelas abrem sem depender de nenhuma cena do SwiftUI estar viva.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    // Enquanto o firmware não existe, o app sempre usa o teclado simulado.
    let store = KeyboardStore.simulated()

    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private var mainWindow: NSWindow?
    private var settingsWindow: NSWindow?

    /// O SwiftUI põe um objeto dele em `NSApp.delegate`; a referência a este fica aqui.
    private(set) static weak var shared: AppDelegate?

    override init() {
        super.init()
        Self.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Appearance.applySaved()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        watchState()

        let content = NSHostingController(rootView: MenuBarView().environment(store))
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        // Aberto pela pessoa (não no login, que usa --hidden): mostra a janela.
        if !CommandLine.arguments.contains("--hidden") { showMain() }
    }

    /// Clicar no Dock ou abrir o app de novo com ele rodando traz a janela.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showMain()
        return true
    }

    // MARK: ícone

    /// Redesenha o ícone a cada mudança do estado do teclado.
    private func watchState() {
        withObservationTracking {
            updateIcon(store.state)
        } onChange: {
            Task { @MainActor [weak self] in self?.watchState() }
        }
    }

    // Animação do ícone: vai do quadro mostrado até o estado novo, quadro a quadro.
    private var shown: (stagger: Double, separation: Double)?
    private var animation: (from: (Double, Double), to: (Double, Double), start: Date, duration: Double, opening: Bool)?
    private var iconTimer: Timer?
    private var iconDimmed = false

    private func updateIcon(_ state: KeyboardState) {
        guard let button = statusItem?.button else { return }
        button.setAccessibilityLabel(Self.accessibilityText(state))
        button.toolTip = Self.accessibilityText(state)
        iconDimmed = !state.isConnected
        let target = (Double(state.staggerPercent), state.halvesJoined ? 0.0 : 1.0)
        guard let current = shown else {
            shown = target
            drawIcon()
            return
        }
        guard current != target else { drawIcon(); return }
        // Abrir é a mola soltando as colunas (mais lento, freia no fim); fechar é empurrar até a trava.
        let opening = target.0 > current.stagger || target.1 > current.separation
        animation = (from: (current.stagger, current.separation), to: target, start: Date(), duration: opening ? 0.55 : 0.35, opening: opening)
        if iconTimer == nil {
            let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.stepIcon() }
            }
            RunLoop.main.add(timer, forMode: .common)
            iconTimer = timer
        }
    }

    private func stepIcon() {
        guard let a = animation else { iconTimer?.invalidate(); iconTimer = nil; return }
        let t = min(Date().timeIntervalSince(a.start) / a.duration, 1)
        let k = a.opening ? 1 - pow(1 - t, 3) : t * t * t
        shown = (a.from.0 + (a.to.0 - a.from.0) * k, a.from.1 + (a.to.1 - a.from.1) * k)
        drawIcon()
        if t >= 1 {
            animation = nil
            iconTimer?.invalidate()
            iconTimer = nil
        }
    }

    private func drawIcon() {
        guard let button = statusItem?.button, let shown else { return }
        var drawing = keyboardGlyphFrame(stagger: Float(shown.stagger), separation: Float(shown.separation))
        drawing.dimmed = iconDimmed
        button.image = MarkRenderer.menuBarImage(drawing)
    }

    static func accessibilityText(_ state: KeyboardState) -> String {
        guard state.isConnected else { return "Yggi, \(state.connectionText.lowercased())" }
        var parts = ["Yggi"]
        parts.append(state.staggerPercent > 0 ? "stagger aberto \(state.staggerPercent)%" : "ortho")
        parts.append(state.halvesJoined ? "metades juntas" : "metades separadas")
        return parts.joined(separator: ", ")
    }

    // MARK: balão

    /// Clique abre o balão; clique direito (ou com control) mostra o menu com janela, ajustes e sair.
    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            closePopover()
            let menu = NSMenu()
            menu.addItem(withTitle: "Abrir Yggi…", action: #selector(menuOpenMain), keyEquivalent: "").target = self
            menu.addItem(withTitle: "Ajustes…", action: #selector(menuOpenSettings), keyEquivalent: ",").target = self
            menu.addItem(.separator())
            menu.addItem(withTitle: "Sair do Yggi", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 4), in: sender)
            return
        }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
            sender.highlight(true)
        }
    }

    @objc private func menuOpenMain() { showMain() }
    @objc private func menuOpenSettings() { showSettings() }

    func popoverDidClose(_ notification: Notification) {
        statusItem?.button?.highlight(false)
    }

    func closePopover() {
        if popover.isShown { popover.performClose(nil) }
    }

    // MARK: janelas

    func showMain(section: AppSection? = nil) {
        closePopover()
        if let section { store.section = section }
        if mainWindow == nil {
            let host = NSHostingController(rootView: MainView().environment(store))
            host.sceneBridgingOptions = [.toolbars, .title]
            // A janela não fica menor que o mínimo das telas (senão o SwiftUI corta as bordas).
            host.sizingOptions = [.minSize]
            let window = NSWindow(contentViewController: host)
            window.title = "Yggi"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.setContentSize(NSSize(width: 1280, height: 820))
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("YggiMainWindow")
            window.center()
            // Abre na mesa (Space) em que a pessoa está, mesmo com outro app em tela cheia.
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            mainWindow = window
        }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    func showSettings() {
        closePopover()
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView().environment(store)))
            window.title = "Ajustes do Yggi"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            window.center()
            settingsWindow = window
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
}

/// Para as telas pedirem janelas sem saber de AppKit.
@MainActor
enum AppWindows {
    static func main(_ section: AppSection? = nil) { AppDelegate.shared?.showMain(section: section) }
    static func settings() { AppDelegate.shared?.showSettings() }
}
