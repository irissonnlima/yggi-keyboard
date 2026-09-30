import AppKit
import SwiftUI
import YggiCore

extension MarkCapsule {
    /// A cápsula em coordenadas do desenho (y para baixo).
    var path: CGPath {
        let length = CGFloat(self.length), width = CGFloat(self.width)
        let rect = CGRect(x: -length / 2, y: -width / 2, width: length, height: width)
        var t = CGAffineTransform(translationX: CGFloat(cx), y: CGFloat(cy)).rotated(by: CGFloat(angle) * .pi / 180)
        return CGPath(roundedRect: rect, cornerWidth: width / 2, cornerHeight: width / 2, transform: &t)
    }
}

/// Um desenho do núcleo (marca ou teclado em miniatura), pintado com o `foregroundStyle`.
struct MarkShape: Shape {
    let drawing: MarkDrawing

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width / CGFloat(drawing.width), rect.height / CGFloat(drawing.height))
        var path = Path()
        for capsule in drawing.capsules { path.addPath(Path(capsule.path)) }
        let dx = rect.midX - CGFloat(drawing.width) * scale / 2
        let dy = rect.midY - CGFloat(drawing.height) * scale / 2
        return path.applying(CGAffineTransform(translationX: dx, y: dy).scaledBy(x: scale, y: scale))
    }
}

/// A marca do Yggi.
struct YggiMark: View {
    var body: some View {
        MarkShape(drawing: yggiMark())
            .aspectRatio(80.0 / 98.0, contentMode: .fit)
            .accessibilityHidden(true)
    }
}

/// O teclado em miniatura (o mesmo da barra de menus): colunas abertas ou não, metades juntas ou não.
/// Anima junto com o estado: as colunas sobem e as metades deslizam.
struct KeyboardGlyph: View {
    let percent: UInt8
    var joined = true

    var body: some View {
        let drawing = keyboardGlyph(staggerPercent: percent, halvesJoined: joined)
        KeyboardGlyphShape(stagger: Double(percent), separation: joined ? 0 : 1)
            .aspectRatio(CGFloat(drawing.width / drawing.height), contentMode: .fit)
            .accessibilityHidden(true)
    }
}

/// Um quadro do teclado em miniatura; o SwiftUI interpola `stagger` e `separation`.
struct KeyboardGlyphShape: Shape {
    var stagger: Double
    var separation: Double

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(stagger, separation) }
        set { (stagger, separation) = (newValue.first, newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        MarkShape(drawing: keyboardGlyphFrame(stagger: Float(stagger), separation: Float(separation))).path(in: rect)
    }
}

enum MarkRenderer {
    /// Imagem-modelo para a barra de menus: o macOS pinta de acordo com o tema e o destaque.
    static func menuBarImage(_ drawing: MarkDrawing, height: CGFloat = 13) -> NSImage {
        let scale = height / CGFloat(drawing.height)
        let size = CGSize(width: (CGFloat(drawing.width) * scale).rounded(.up), height: height)
        let image = NSImage(size: size, flipped: true) { rect in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            cg.translateBy(x: (rect.width - CGFloat(drawing.width) * scale) / 2, y: 0)
            cg.scaleBy(x: scale, y: scale)
            cg.setFillColor(NSColor.black.withAlphaComponent(drawing.dimmed ? 0.35 : 1).cgColor)
            for capsule in drawing.capsules { cg.addPath(capsule.path) }
            cg.fillPath()
            return true
        }
        image.isTemplate = true
        return image
    }
}
