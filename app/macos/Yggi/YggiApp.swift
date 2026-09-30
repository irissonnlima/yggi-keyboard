import SwiftUI
import YggiCore

@main
struct YggiApp: App {
    // Enquanto o firmware não existe, o app sempre usa o teclado simulado.
    @State private var store = KeyboardStore.simulated()

    init() {
        #if DEBUG
        Snapshots.runIfRequested()
        #endif
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environment(store)
                .onAppear(perform: applyAppearance)
        } label: {
            MenuBarLabel(state: store.state)
        }
        .menuBarExtraStyle(.window)

        Window("Yggi", id: WindowID.main) {
            MainView()
                .environment(store)
                .onAppear(perform: applyAppearance)
        }
        .defaultSize(width: 1280, height: 820)

        Settings {
            SettingsView()
        }
    }

    private func applyAppearance() {
        let raw = UserDefaults.standard.string(forKey: Appearance.storageKey) ?? Appearance.system.rawValue
        (Appearance(rawValue: raw) ?? .system).apply()
    }
}

enum WindowID {
    static let main = "main"
}
