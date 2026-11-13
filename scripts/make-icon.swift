// Draws the app icon: the menu bar's cat on a macOS-style white rounded
// square. Compiled together with Sources/IslandCat/CatIcon.swift by
// scripts/make-icon.sh, which turns its PNGs into Resources/AppIcon.icns.
import AppKit

/// The icon at `pixels` square, drawn on Apple's 1024 pt grid.
func render(pixels: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 1024, height: 1024)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    // An 824 pt rounded square with a soft shadow below it.
    let tile = NSBezierPath(
        roundedRect: NSRect(x: 100, y: 100, width: 824, height: 824), xRadius: 185, yRadius: 185)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowBlurRadius = 20
    shadow.set()
    NSColor.white.setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(
        starting: .white, ending: NSColor(srgbRed: 0.91, green: 0.91, blue: 0.93, alpha: 1))!
        .draw(in: tile, angle: -90)
    // The menu bar's cat, 22 times its size there.
    let cat = CatIcon.image()
    let size = NSSize(width: cat.size.width * 22, height: cat.size.height * 22)
    cat.draw(in: NSRect(
        x: 512 - size.width / 2, y: 512 - size.height / 2 + 8,
        width: size.width, height: size.height))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconset = URL(fileURLWithPath: CommandLine.arguments[1])
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for points in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
        try render(pixels: points * scale).representation(using: .png, properties: [:])!
            .write(to: iconset.appendingPathComponent(name))
    }
}
