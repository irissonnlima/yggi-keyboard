// Gera os PNGs do ícone do app a partir de docs/brand/yggi-icone.svg.
// Uso (da pasta app): swift scripts/make-icons.swift
import AppKit

let svg = URL(fileURLWithPath: "../docs/brand/yggi-icone.svg")
let out = URL(fileURLWithPath: "macos/Yggi/Assets.xcassets/AppIcon.appiconset")
guard let image = NSImage(contentsOf: svg) else { fatalError("não li \(svg.path)") }
try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

var entries: [String] = []
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = points * scale
        let name = "icone-\(points)@\(scale)x.png"
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
                                   samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                                   bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels))
        NSGraphicsContext.restoreGraphicsState()
        try rep.representation(using: .png, properties: [:])!.write(to: out.appending(path: name))
        entries.append(#"    { "idiom" : "mac", "size" : "\#(points)x\#(points)", "scale" : "\#(scale)x", "filename" : "\#(name)" }"#)
    }
}
let json = "{\n  \"images\" : [\n" + entries.joined(separator: ",\n") + "\n  ],\n  \"info\" : { \"author\" : \"xcode\", \"version\" : 1 }\n}\n"
try json.write(to: out.appending(path: "Contents.json"), atomically: true, encoding: .utf8)
print("✓ ícone em \(out.path)")
