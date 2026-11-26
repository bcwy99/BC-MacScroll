// Draws the BC MacScroll app icon and writes Resources/AppIcon.icns.
// Usage: swift scripts/make-icon.swift
import AppKit

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = size / 1024

    // macOS icon grid: 824pt rounded square centred in 1024 with a soft shadow.
    let tile = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let shape = NSBezierPath(roundedRect: tile, xRadius: 185 * s, yRadius: 185 * s)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowBlurRadius = 28 * s
    shadow.shadowOffset = NSSize(width: 0, height: -12 * s)
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
    shadow.set()
    NSColor.black.setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()

    NSGraphicsContext.saveGraphicsState()
    shape.addClip()
    NSGradient(colors: [NSColor(srgbRed: 0.33, green: 0.27, blue: 0.95, alpha: 1),
                        NSColor(srgbRed: 0.10, green: 0.62, blue: 0.93, alpha: 1)])!
        .draw(in: tile, angle: -60)
    // Soft highlight on the upper half.
    NSGradient(colorsAndLocations: (NSColor.white.withAlphaComponent(0), 0.35),
                                   (NSColor.white.withAlphaComponent(0.16), 1.0))!
        .draw(in: tile, angle: 90)
    NSGraphicsContext.restoreGraphicsState()

    func symbol(_ name: String, pointSize: CGFloat, weight: NSFont.Weight) -> NSImage {
        let config = NSImage.SymbolConfiguration(pointSize: pointSize, weight: weight)
            .applying(.init(paletteColors: [.white]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)!.withSymbolConfiguration(config)!
    }

    // Mouse, slightly left of centre.
    let mouse = symbol("computermouse.fill", pointSize: 430 * s, weight: .regular)
    let mSize = mouse.size
    mouse.draw(in: NSRect(x: 375 * s - mSize.width / 2, y: 505 * s - mSize.height / 2,
                          width: mSize.width, height: mSize.height))

    // Up/down arrows to the right.
    let arrows = symbol("arrow.up.arrow.down", pointSize: 230 * s, weight: .bold)
    let aSize = arrows.size
    arrows.draw(in: NSRect(x: 712 * s - aSize.width / 2, y: 505 * s - aSize.height / 2,
                           width: aSize.width, height: aSize.height),
                from: .zero, operation: .sourceOver, fraction: 0.92)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let iconset = FileManager.default.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconset)
try! FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = CGFloat(base * scale)
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! drawIcon(size: px).representation(using: .png, properties: [:])!
            .write(to: iconset.appendingPathComponent(name))
    }
}
try! drawIcon(size: 512).representation(using: .png, properties: [:])!
    .write(to: root.appendingPathComponent("docs/icon.png"))

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", root.appendingPathComponent("Resources/AppIcon.icns").path]
try! task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "Wrote Resources/AppIcon.icns" : "iconutil failed")
