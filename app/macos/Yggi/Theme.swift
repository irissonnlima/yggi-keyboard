import SwiftUI
import YggiCore

/// Aparência escolhida em Ajustes. "Sistema" segue o macOS.
enum Appearance: String, CaseIterable, Identifiable {
    case system = "sistema"
    case light = "claro"
    case dark = "escuro"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "Sistema"
        case .light: "Claro"
        case .dark: "Escuro"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    static let storageKey = "appearance"
}

/// Cores do produto físico: não mudam com o tema do app.
enum Hardware {
    static let caseColor = Color(red: 0x2e / 255, green: 0x30 / 255, blue: 0x35 / 255)
    static let skirt = Color(red: 0x3b / 255, green: 0x3e / 255, blue: 0x44 / 255)
    static let keyAlpha = Color(red: 0xf7 / 255, green: 0xf6 / 255, blue: 0xf2 / 255)
    static let keyModifier = Color(red: 0xe2 / 255, green: 0xe1 / 255, blue: 0xdc / 255)
    static let keyYggi = Color(red: 0x1f / 255, green: 0x6f / 255, blue: 0x5c / 255)
    static let legend = Color(red: 0x26 / 255, green: 0x27 / 255, blue: 0x2b / 255)
    static let ledOff = Color(red: 0x4a / 255, green: 0x4d / 255, blue: 0x53 / 255)
    static let eInk = Color(red: 0xdc / 255, green: 0xda / 255, blue: 0xd1 / 255)
    static let eInkText = Color(red: 0x2a / 255, green: 0x2a / 255, blue: 0x28 / 255)
    static let pogo = Color(red: 0xb8 / 255, green: 0x95 / 255, blue: 0x45 / 255)
}

/// Cor de destaque da tecla Yggi em textos, legível nos dois temas.
extension ShapeStyle where Self == Color {
    static var yggiText: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                ? NSColor(red: 0x5f / 255, green: 0xd6 / 255, blue: 0xb6 / 255, alpha: 1)
                : NSColor(red: 0x1f / 255, green: 0x6f / 255, blue: 0x5c / 255, alpha: 1)
        })
    }
}

extension Color {
    init(_ rgb: Rgb) {
        self.init(red: Double(rgb.r) / 255, green: Double(rgb.g) / 255, blue: Double(rgb.b) / 255)
    }
}

extension Rgb {
    init(_ color: Color) {
        let c = NSColor(color).usingColorSpace(.sRGB) ?? .white
        self.init(r: UInt8(max(0, min(255, (c.redComponent * 255).rounded()))),
                  g: UInt8(max(0, min(255, (c.greenComponent * 255).rounded()))),
                  b: UInt8(max(0, min(255, (c.blueComponent * 255).rounded()))))
    }

    var hex: String { String(format: "#%02x%02x%02x", r, g, b) }

    /// Cor da legenda acesa: cores muito claras escurecem um pouco para ler sobre a tecla clara.
    var legendColor: Color {
        let lum = (0.299 * Double(r) + 0.587 * Double(g) + 0.114 * Double(b)) / 255
        let f = lum > 0.8 ? 0.55 : (lum > 0.55 ? 0.75 : 1)
        return Color(red: Double(r) / 255 * f, green: Double(g) / 255 * f, blue: Double(b) / 255 * f)
    }
}

/// Cartão branco (ou cinza-escuro) das telas, como nos Ajustes do macOS.
struct Card<Content: View>: View {
    var padding: CGFloat = 14
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(.background))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.separator.opacity(0.6), lineWidth: 0.5))
    }
}

struct SimulatedTag: View {
    var body: some View {
        Text("simulado")
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(.orange.opacity(0.2)))
            .foregroundStyle(.orange)
            .help("O firmware ainda não existe: este teclado é simulado pelo núcleo.")
    }
}

/// Seletor de cor: tons prontos + seletor livre do sistema.
struct ColorChooser: View {
    @Binding var color: Rgb
    var size: CGFloat = 20

    var body: some View {
        HStack(spacing: 6) {
            ForEach(lightingPalette(), id: \.self) { swatch in
                Button {
                    color = swatch
                } label: {
                    Circle()
                        .fill(Color(swatch))
                        .frame(width: size, height: size)
                        .overlay(Circle().strokeBorder(.black.opacity(0.12), lineWidth: 0.5))
                        .padding(2)
                        .overlay(Circle().strokeBorder(color == swatch ? Color(swatch) : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(swatch.hex)
            }
            ColorPicker("Outra cor", selection: Binding(
                get: { Color(color) },
                set: { color = Rgb($0) }
            ), supportsOpacity: false)
            .labelsHidden()
            .help("Outra cor")
        }
    }
}
