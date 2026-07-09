// Renders a modern app icon using an SF Symbol (Apple's free, built-in icon
// set - no external licensing) on a rounded gradient background.
// Usage: swift scripts/make_icon.swift /tmp/bitrail_icon_source.png
import AppKit

let outputPath = CommandLine.arguments[1]
let size: CGFloat = 1024

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let rect = NSRect(x: 0, y: 0, width: size, height: size)
let corner = size * 0.22
let path = NSBezierPath(roundedRect: rect, xRadius: corner, yRadius: corner)

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.30, green: 0.20, blue: 0.85, alpha: 1),
    NSColor(calibratedRed: 0.15, green: 0.55, blue: 0.95, alpha: 1)
])
gradient?.draw(in: path, angle: -45)

if let symbolImage = NSImage(systemSymbolName: "waveform.badge.plus", accessibilityDescription: nil) {
    let config = NSImage.SymbolConfiguration(pointSize: size * 0.5, weight: .semibold)
        .applying(NSImage.SymbolConfiguration(paletteColors: [.white]))
    let tinted = symbolImage.withSymbolConfiguration(config) ?? symbolImage
    let symbolSize = tinted.size
    let scale = (size * 0.55) / max(symbolSize.width, symbolSize.height)
    let drawSize = NSSize(width: symbolSize.width * scale, height: symbolSize.height * scale)
    let origin = NSPoint(x: (size - drawSize.width) / 2, y: (size - drawSize.height) / 2)
    tinted.draw(in: NSRect(origin: origin, size: drawSize), from: .zero, operation: .sourceOver, fraction: 1)
}

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Could not render icon")
}

try png.write(to: URL(fileURLWithPath: outputPath))
print("Wrote \(outputPath)")
