import SwiftUI
import YggiCore

@main
struct YggiApp: App {
    /// Ícone da barra, balão e janelas ficam no AppDelegate (AppKit).
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var app

    init() {
        #if DEBUG
        Snapshots.runIfRequested()
        #endif
    }

    var body: some Scene {
        // As janelas são abertas pelo AppDelegate; daqui vêm só os menus do app.
        Settings { EmptyView() }
            .commands {
                CommandGroup(replacing: .appSettings) {
                    Button("Ajustes…") { AppWindows.settings() }
                        .keyboardShortcut(",")
                }
                CommandGroup(replacing: .newItem) {
                    Button("Janela do Yggi") { AppWindows.main() }
                        .keyboardShortcut("0")
                }
            }
    }
}
