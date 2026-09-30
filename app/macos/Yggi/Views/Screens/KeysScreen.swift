import SwiftUI
import YggiCore

/// Teclas e camadas. Por enquanto só leitura: a edição chega com o protocolo do ZMK Studio,
/// quando o firmware existir.
struct KeysScreen: View {
    @Environment(KeyboardStore.self) private var store
    @State private var selected: KeyDef?

    var body: some View {
        VStack(spacing: 16) {
            FittedKeyboard { unit in
                LiveKeyboard(selectedKey: selected?.id, lightsOn: false, unit: unit) { key in
                    selected = key
                }
            }
            Card {
                HStack(alignment: .top, spacing: 28) {
                    VStack(spacing: 8) {
                        Text(selected?.label ?? "—")
                            .font(.callout.weight(.medium))
                            .foregroundStyle(Hardware.legend)
                            .frame(width: 96, height: 60)
                            .background(RoundedRectangle(cornerRadius: 9).fill(Hardware.keyModifier))
                            .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(Color.accentColor, lineWidth: 2))
                        Text("camada base").font(.caption).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        if let key = selected {
                            Text(key.name).font(.headline)
                            LabeledContent("Comportamento", value: "Tecla (layout Mac padrão)")
                            LabeledContent("Envia", value: key.label)
                        } else {
                            Text("Clique numa tecla para ver o que ela faz.").foregroundStyle(.secondary)
                        }
                        Label("A edição de teclas, camadas e macros chega com o protocolo do ZMK Studio, quando o firmware existir.",
                              systemImage: "info.circle")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    Spacer(minLength: 0)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .navigationTitle("Teclas e camadas")
        .navigationSubtitle("Protocolo ZMK Studio")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Picker("Camada", selection: .constant(0)) {
                    Text("Base").tag(0)
                    Text("fn").tag(1)
                }
                .pickerStyle(.segmented)
                .disabled(true)
            }
        }
    }
}
