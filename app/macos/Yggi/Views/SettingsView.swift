import SwiftUI

/// Ajustes (⌘,). A aparência segue o sistema por padrão.
struct SettingsView: View {
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system
    @AppStorage("openAtLogin") private var openAtLogin = true
    @AppStorage("showInMenuBar") private var showInMenuBar = true
    @AppStorage("lowBatteryAlert") private var lowBatteryAlert = true
    @AppStorage("switchSound") private var switchSound = false
    @AppStorage("keyboardName") private var keyboardName = "Yggi"

    var body: some View {
        Form {
            Section {
                LabeledContent("Aparência") {
                    HStack(spacing: 14) {
                        ForEach(Appearance.allCases) { option in
                            AppearanceThumb(option: option, selected: appearance == option) {
                                appearance = option
                            }
                        }
                    }
                }
            }
            Section {
                Toggle(isOn: $openAtLogin) {
                    Text("Abrir ao iniciar sessão")
                    Text("O app fica na barra de menus desde o início")
                }
                Toggle(isOn: $showInMenuBar) {
                    Text("Mostrar na barra de menus")
                    Text("Bateria e computador ativo sempre à vista")
                }
                Toggle(isOn: $lowBatteryAlert) {
                    Text("Avisar bateria baixa")
                    Text("Notificação quando uma metade passar de 15%")
                }
                Toggle(isOn: $switchSound) {
                    Text("Som ao trocar de computador")
                    Text("Um clique discreto quando a tecla yggi troca")
                }
            }
            Section {
                TextField("Nome do teclado", text: $keyboardName)
                LabeledContent {
                    Picker("Fonte dos dados", selection: .constant(0)) {
                        Text("Simulado").tag(0)
                        Text("Bluetooth").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .fixedSize()
                } label: {
                    Text("Fonte dos dados")
                    Text("Enquanto o firmware não existe, o app usa o teclado simulado")
                }
            }
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .frame(width: 560)
        .fixedSize(horizontal: false, vertical: true)
        .onChange(of: appearance, initial: true) { _, value in
            value.apply()
        }
    }
}

extension Appearance {
    /// Aplica no app inteiro (janela, barra de menus e ajustes).
    @MainActor func apply() {
        NSApp.appearance = switch self {
        case .system: nil
        case .light: NSAppearance(named: .aqua)
        case .dark: NSAppearance(named: .darkAqua)
        }
    }
}

private struct AppearanceThumb: View {
    let option: Appearance
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    half(dark: option == .dark)
                    half(dark: option != .light)
                }
                .frame(width: 72, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(.separator, lineWidth: 0.5))
                .padding(2)
                .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 2))
                Text(option.title)
                    .font(.caption)
                    .fontWeight(selected ? .semibold : .regular)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func half(dark: Bool) -> some View {
        let bg = dark ? Color(white: 0.17) : Color(white: 0.96)
        let ink = dark ? Color(white: 0.4) : Color(white: 0.78)
        return VStack(alignment: .leading, spacing: 3) {
            Capsule().fill(ink).frame(width: 22, height: 4)
            Capsule().fill(ink).frame(width: 28, height: 4)
            Spacer()
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
    }
}
