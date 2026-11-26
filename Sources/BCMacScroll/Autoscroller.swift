//
//  Autoscroller.swift
//  BC MacScroll
//
//  Windows-style middle-click autoscroll.
//  - Click the middle button: an indicator appears; move the mouse away from it
//    to scroll, further = faster. Click any button (or scroll the wheel) to stop.
//  - Hold the middle button and drag: scrolls while held, stops on release.
//

import Cocoa

final class Autoscroller {

    static let shared = Autoscroller()

    /// Tag put on the scroll events we post, so the event tap lets them through untouched.
    static let syntheticMarker: Int64 = 0x5553_5721

    private let deadzone: CGFloat = 8
    private let lock = NSLock()

    // State shared between the event-tap thread and the main thread (guarded by `lock`).
    private var active = false
    private var anchor = CGPoint.zero          // global CG coordinates (top-left origin)
    private var middleHeld = false
    private var swallowUpForButton: Int64? = nil

    // Main-thread only.
    private var timer: Timer?
    private var indicator: NSPanel?
    private var remainder = CGPoint.zero

    // MARK: - Event tap entry point (runs on the tap thread)

    /// Returns true when the event should be swallowed.
    func handle(type: CGEventType, event: CGEvent) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard Settings.shared.autoscrollEnabled else {
            if active { stopLocked() }
            return false
        }

        let button = event.getIntegerValueField(.mouseEventButtonNumber)

        switch type {
        case .otherMouseDown where button == 2:
            if active {
                stopLocked()
                swallowUpForButton = 2
            } else {
                startLocked(at: event.location)
            }
            return true

        case .otherMouseUp where button == 2:
            if swallowUpForButton == 2 {
                swallowUpForButton = nil
                return true
            }
            if active && middleHeld {
                middleHeld = false
                // Held-and-dragged: releasing ends the scroll. A plain click keeps it going.
                if distance(event.location, anchor) > deadzone * 2 {
                    stopLocked()
                }
                return true
            }
            return false

        case .leftMouseDown, .rightMouseDown, .otherMouseDown:
            guard active else { return false }
            // Any other click ends autoscroll and is consumed, like on Windows.
            stopLocked()
            swallowUpForButton = button
            return true

        case .leftMouseUp, .rightMouseUp, .otherMouseUp:
            if swallowUpForButton == button {
                swallowUpForButton = nil
                return true
            }
            return false

        case .scrollWheel:
            // Real wheel movement cancels autoscroll and goes through normally.
            if active { stopLocked() }
            return false

        default:
            return false
        }
    }

    // MARK: - Start / stop (lock held)

    private func startLocked(at point: CGPoint) {
        active = true
        middleHeld = true
        anchor = point
        DispatchQueue.main.async { self.startUI(at: point) }
    }

    private func stopLocked() {
        active = false
        middleHeld = false
        DispatchQueue.main.async { self.stopUI() }
    }

    // MARK: - Main thread

    private func startUI(at point: CGPoint) {
        remainder = .zero
        showIndicator(at: point)
        timer?.invalidate()
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func stopUI() {
        lock.lock()
        let stillActive = active
        lock.unlock()
        guard !stillActive else { return }   // a new session started meanwhile
        timer?.invalidate()
        timer = nil
        indicator?.orderOut(nil)
    }

    private func tick() {
        lock.lock()
        let isActive = active
        let origin = anchor
        lock.unlock()
        guard isActive else { return }

        let cursor = currentCursorCG()
        let vx = speed(cursor.x - origin.x) + remainder.x
        let vy = speed(cursor.y - origin.y) + remainder.y
        let ix = vx.rounded(.towardZero)
        let iy = vy.rounded(.towardZero)
        remainder = CGPoint(x: vx - ix, y: vy - iy)
        guard ix != 0 || iy != 0 else { return }

        // Pointer below the anchor => move further down the page (negative delta), etc.
        guard let scroll = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2,
                                   wheel1: Int32(-iy), wheel2: Int32(-ix), wheel3: 0) else { return }
        scroll.setIntegerValueField(.eventSourceUserData, value: Autoscroller.syntheticMarker)
        // Post at the session level and leave the location alone: posting at the
        // HID level with a location warps the real cursor back to that point,
        // which pinned the pointer to the anchor and made scrolling stutter.
        scroll.post(tap: .cgSessionEventTap)
    }

    /// Pixels to scroll per frame for a given pointer offset.
    private func speed(_ offset: CGFloat) -> CGFloat {
        let a = abs(offset) - deadzone
        guard a > 0 else { return 0 }
        let v = min((0.15 * a + 0.002 * a * a) * CGFloat(Settings.shared.autoscrollSpeed), 160)
        return offset < 0 ? -v : v
    }

    private func currentCursorCG() -> CGPoint {
        if let e = CGEvent(source: nil) { return e.location }
        let p = NSEvent.mouseLocation
        let h = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: p.x, y: h - p.y)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }

    // MARK: - Indicator

    private func showIndicator(at cgPoint: CGPoint) {
        let size: CGFloat = 34
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        let center = NSPoint(x: cgPoint.x, y: primaryHeight - cgPoint.y)
        let frame = NSRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)

        if indicator == nil {
            let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                                backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.level = .popUpMenu
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            panel.contentView = AutoscrollIndicatorView(frame: NSRect(origin: .zero, size: frame.size))
            indicator = panel
        }
        indicator?.setFrame(frame, display: true)
        indicator?.orderFrontRegardless()
    }
}

/// The round marker shown where autoscroll started: a frosted disc with
/// four arrows and a centre dot, tinted with the system accent colour.
final class AutoscrollIndicatorView: NSView {
    override var isFlipped: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        let r = bounds.insetBy(dx: 1.5, dy: 1.5)
        let disc = NSBezierPath(ovalIn: r)

        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowBlurRadius = 3
        shadow.shadowOffset = NSSize(width: 0, height: -1)
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
        shadow.set()
        NSColor.white.withAlphaComponent(0.96).setFill()
        disc.fill()
        NSGraphicsContext.restoreGraphicsState()

        let accent = NSColor.controlAccentColor
        accent.withAlphaComponent(0.9).setStroke()
        disc.lineWidth = 1.5
        disc.stroke()

        let c = NSPoint(x: bounds.midX, y: bounds.midY)
        let unit = bounds.width / 34
        accent.setFill()
        let dot = 2.2 * unit
        NSBezierPath(ovalIn: NSRect(x: c.x - dot, y: c.y - dot, width: dot * 2, height: dot * 2)).fill()

        func triangle(_ p1: NSPoint, _ p2: NSPoint, _ p3: NSPoint) {
            let t = NSBezierPath()
            t.move(to: p1); t.line(to: p2); t.line(to: p3); t.close(); t.fill()
        }
        let s = 4.5 * unit, gap = 6 * unit
        NSColor.black.withAlphaComponent(0.72).setFill()
        triangle(NSPoint(x: c.x, y: c.y + gap + s), NSPoint(x: c.x - s, y: c.y + gap), NSPoint(x: c.x + s, y: c.y + gap))
        triangle(NSPoint(x: c.x, y: c.y - gap - s), NSPoint(x: c.x - s, y: c.y - gap), NSPoint(x: c.x + s, y: c.y - gap))
        triangle(NSPoint(x: c.x - gap - s, y: c.y), NSPoint(x: c.x - gap, y: c.y + s), NSPoint(x: c.x - gap, y: c.y - s))
        triangle(NSPoint(x: c.x + gap + s, y: c.y), NSPoint(x: c.x + gap, y: c.y + s), NSPoint(x: c.x + gap, y: c.y - s))
    }
}
