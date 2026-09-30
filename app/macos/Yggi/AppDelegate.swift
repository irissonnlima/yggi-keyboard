import AppKit
import Observation
import SwiftUI
import YggiCore

/// Ícone na barra de menus, balão com os widgets e janelas do app.
///
/// O Yggi é um app normal (Dock, Cmd+Tab, janela comum) que também tem o ícone na barra.
/// Feito em AppKit: o `NSStatusItem` com `NSPopover` dá o balão com a setinha apontando para
/// o ícone, e as janelas abrem sem depender de nenhuma cena do SwiftUI estar viva.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    // Enquanto o firmware não existe, o app sempre usa o teclado simulado.
    let store = KeyboardStore.simulated()

    private var statusItem: NSStatusItem?
    private var icon: MenuBarIcon?
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
        NSApp.setActivationPolicy(.regular)

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.target = self
        item.button?.action = #selector(togglePopover(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem = item
        icon = MenuBarIcon(store: store) { [weak item] image, description in
            item?.button?.image = image
            item?.button?.toolTip = description
            item?.button?.setAccessibilityLabel(description)
        }

        let content = NSHostingController(rootView: MenuBarView().environment(store))
        content.sizingOptions = .preferredContentSize
        popover.contentViewController = content
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self

        // Aberto pela pessoa (não no login, que usa --hidden): mostra a janela.
        if !CommandLine.arguments.contains("--hidden") { showMain(section: Self.sectionArgument) }
    }

    /// `--section barra` abre a janela direto numa seção (útil para testar).
    private static var sectionArgument: AppSection? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--section"), args.indices.contains(i + 1) else { return nil }
        return switch args[i + 1] {
        case "teclas": .keys
        case "luzes": .lights
        case "estatisticas": .stats
        case "barra": .menuBar
        default: .overview
        }
    }

    /// Clicar no Dock ou abrir o app de novo com ele rodando traz a janela.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        showMain()
        return true
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
        if mainWindow == nil { mainWindow = Self.makeMainWindow(store: store) }
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    /// A janela principal: comum (nem sempre por cima, nem em todas as mesas) e nunca menor que o
    /// mínimo das telas. `--verificar` confere essas regras.
    static func makeMainWindow(store: KeyboardStore) -> NSWindow {
        let host = NSHostingController(rootView: MainView().environment(store))
        host.sceneBridgingOptions = [.toolbars, .title]
        // A janela não fica menor que o mínimo das telas (senão o SwiftUI corta as bordas).
        host.sizingOptions = [.minSize]
        let window = NSWindow(contentViewController: host)
        window.title = "Yggi"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.setContentSize(NSSize(width: 1400, height: 860))
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("YggiWindow")
        window.center()
        return window
    }

    func showSettings() {
        closePopover()
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView().environment(store)))
            window.title = "Ajustes do Yggi"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
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
