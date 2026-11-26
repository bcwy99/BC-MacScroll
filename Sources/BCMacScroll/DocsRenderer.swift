//
//  DocsRenderer.swift
//  BC MacScroll
//
//  Renders the app's real SwiftUI views offscreen into PNGs for the README,
//  so the screenshots always match the current UI. Run via:
//      "BC MacScroll.app/Contents/MacOS/BCMacScroll" --render-docs docs/screenshots
//

import AppKit
import SwiftUI

enum DocsRenderer {

    static func render(to folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let permissions = PermissionMonitor.shared

        for dark in [false, true] {
            let suffix = dark ? "dark" : "light"
            permissions.trusted = true
            save(SettingsView(scrollable: false), dark: dark, to: folder.appendingPathComponent("settings-\(suffix).png"))
            permissions.trusted = false
            save(WelcomeView(), dark: dark, to: folder.appendingPathComponent("welcome-\(suffix).png"))
            permissions.trusted = true
            save(WelcomeView(), dark: dark, to: folder.appendingPathComponent("welcome-granted-\(suffix).png"))
        }

        // The autoscroll marker, enlarged.
        let marker = AutoscrollIndicatorView(frame: NSRect(x: 0, y: 0, width: 102, height: 102))
        writePNG(snapshot(of: marker, dark: false), to: folder.appendingPathComponent("autoscroll-indicator.png"), chrome: false)
        print("Rendered screenshots to \(folder.path)")
    }

    private static func save<V: View>(_ view: V, dark: Bool, to url: URL) {
        let host = NSHostingView(rootView: view)
        writePNG(snapshot(of: host, dark: dark), to: url, chrome: true)
    }

    private static func snapshot(of view: NSView, dark: Bool) -> NSBitmapImageRep {
        let appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        view.appearance = appearance
        let size = view.fittingSize.width > 0 ? view.fittingSize : view.frame.size
        let window = KeyWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = appearance
        window.contentView = view
        view.frame = NSRect(origin: .zero, size: size)

        // Let SwiftUI finish layout and draw its AppKit-backed controls.
        for _ in 0..<5 {
            view.layoutSubtreeIfNeeded()
            view.display()
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }

        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        rep.size = size
        appearance?.performAsCurrentDrawingAppearance {
            view.cacheDisplay(in: view.bounds, to: rep)
        }
        return rep
    }

    /// Optionally adds rounded corners and a soft shadow so the PNG looks like a window.
    private static func writePNG(_ rep: NSBitmapImageRep, to url: URL, chrome: Bool) {
        guard chrome else {
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
            return
        }
        let content = rep.size
        let pad: CGFloat = 30
        let canvas = NSSize(width: content.width + pad * 2, height: content.height + pad * 2)
        let out = NSBitmapImageRep(bitmapDataPlanes: nil,
                                   pixelsWide: Int(canvas.width * 2), pixelsHigh: Int(canvas.height * 2),
                                   bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                   colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        out.size = canvas

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: out)
        let rect = NSRect(x: pad, y: pad, width: content.width, height: content.height)
        let shape = NSBezierPath(roundedRect: rect, xRadius: 12, yRadius: 12)

        let shadow = NSShadow()
        shadow.shadowBlurRadius = 18
        shadow.shadowOffset = NSSize(width: 0, height: -6)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        NSGraphicsContext.saveGraphicsState()
        shadow.set()
        NSColor.black.setFill()
        shape.fill()
        NSGraphicsContext.restoreGraphicsState()

        shape.addClip()
        rep.draw(in: rect)
        NSGraphicsContext.restoreGraphicsState()

        try? out.representation(using: .png, properties: [:])?.write(to: url)
    }
}

/// Offscreen windows are never key, which makes switches and default buttons
/// draw in their inactive grey. Pretending to be key renders them as users see them.
private final class KeyWindow: NSWindow {
    override var isKeyWindow: Bool { true }
    override var isMainWindow: Bool { true }
    override var canBecomeKey: Bool { true }
}
