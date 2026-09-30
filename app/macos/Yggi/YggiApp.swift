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
        // O app vive na barra de menus (LSUIElement); as janelas são abertas pelo AppDelegate.
        Settings { EmptyView() }
    }
}
