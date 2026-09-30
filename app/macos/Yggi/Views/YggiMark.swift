import AppKit
import SwiftUI
import YggiCore

extension MarkCapsule {
    /// A cápsula em coordenadas da marca (y para baixo), encolhida em `inset` de cada lado.
    func path(inset: CGFloat = 0) -> CGPath {
        let length = CGFloat(self.length) - inset * 2
        let width = max(CGFloat(self.width) - inset * 2, 0.1)
        let rect = CGRect(x: -length / 2, y: -width / 2, width: length, height: width)
        var t = CGAffineTransform(translationX: CGFloat(cx), y: CGFloat(cy)).rotated(by: CGFloat(angle) * .pi / 180)
        return CGPath(roundedRect: rect, cornerWidth: width / 2, cornerHeight: width / 2, transform: &t)
    }
}

/// A marca do Yggi numa pose, para usar em SwiftUI (pinta com o `foregroundStyle`).
struct YggiMark: Shape {
    var pose = MarkPose(open: false, separated: false, outline: false, lowBattery: false)
    /// Traço das partes vazadas, na escala da marca (98 de altura).
    var line: CGFloat = 7

    func path(in rect: CGRect) -> Path {
        let drawing = yggiMark(pose: pose)
        let scale = min(rect.width / CGFloat(drawing.width), rect.height / CGFloat(drawing.height))
        var path = Path()
        for capsule in drawing.capsules {
            if capsule.hollow {
                path.addPath(Path(capsule.path(inset: line / 2).copy(strokingWithWidth: line, lineCap: .round, lineJoin: .round, miterLimit: 1)))
            } else {
                path.addPath(Path(capsule.path()))
            }
        }
        let dx = rect.midX - CGFloat(drawing.width) * scale / 2
        let dy = rect.midY - CGFloat(drawing.height) * scale / 2
        return path.applying(CGAffineTransform(translationX: dx, y: dy).scaledBy(x: scale, y: scale))
    }
}

enum MarkRenderer {
    /// Desenha a marca ocupando `size`, com a cor de preenchimento atual do contexto.
    static func draw(_ drawing: MarkDrawing, in cg: CGContext, size: CGSize, line: CGFloat, color: CGColor = .black) {
        let scale = min(size.width / CGFloat(drawing.width), size.height / CGFloat(drawing.height))
        cg.saveGState()
        cg.translateBy(x: (size.width - CGFloat(drawing.width) * scale) / 2, y: (size.height - CGFloat(drawing.height) * scale) / 2)
        cg.scaleBy(x: scale, y: scale)
        cg.setFillColor(color)
        cg.setStrokeColor(color)
        let lineUnits = line / scale
        for capsule in drawing.capsules {
            if capsule.hollow {
                cg.addPath(capsule.path(inset: lineUnits / 2))
                cg.setLineWidth(lineUnits)
                cg.strokePath()
            } else {
                cg.addPath(capsule.path())
                cg.fillPath()
            }
        }
        cg.restoreGState()
    }

    /// Imagem-modelo para a barra de menus: o macOS pinta de acordo com o tema e o destaque.
    static func menuBarImage(pose: MarkPose, height: CGFloat = 17) -> NSImage {
        let drawing = yggiMark(pose: pose)
        let size = CGSize(width: (height * CGFloat(drawing.width) / CGFloat(drawing.height)).rounded(.up), height: height)
        let image = NSImage(size: size, flipped: true) { rect in
            guard let cg = NSGraphicsContext.current?.cgContext else { return false }
            draw(drawing, in: cg, size: rect.size, line: 1.25)
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Yggi"
        return image
    }
}
