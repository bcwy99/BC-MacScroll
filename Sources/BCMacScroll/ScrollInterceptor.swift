//
//  ScrollInterceptor.swift
//  BC MacScroll
//
//  Originally written by Theron Tjapkes for UnnaturalScrollWheels (GPL-3.0).
//  Modified for BC MacScroll: master on/off switch, middle-click autoscroll.
//

import Foundation
import CoreGraphics
import AppKit

final class ScrollInterceptor {

    static let shared = ScrollInterceptor()

    private let stateLock = NSLock()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var isIntercepting = false
    private var wakeObserver: NSObjectProtocol?

    static let eventMask: CGEventMask = [
        CGEventType.scrollWheel,
        .leftMouseDown, .leftMouseUp,
        .rightMouseDown, .rightMouseUp,
        .otherMouseDown, .otherMouseUp,
    ].reduce(0) { $0 | (CGEventMask(1) << $1.rawValue) }

    // Where the magic happens
    let scrollEventCallback: CGEventTapCallBack = { (proxy: CGEventTapProxy, type: CGEventType, event: CGEvent, refcon) in
        // macOS disables the event tap when the callback takes too long, on
        // heavy input, and when the system wakes from sleep / low-battery
        // standby. When that happens the OS delivers one final event of type
        // .tapDisabledByTimeout / .tapDisabledByUserInput. If we don't re-enable
        // the tap here, scroll interception silently dies and the app appears
        // frozen until it is force quit and relaunched (issues #66, #97, #117).
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            ScrollInterceptor.shared.reEnableTap()
            return Unmanaged.passUnretained(event)
        }

        // Paused from the menu: leave everything alone.
        guard Settings.shared.enabled else {
            return Unmanaged.passUnretained(event)
        }

        // Our own autoscroll events: pass through untouched.
        if type == .scrollWheel && event.getIntegerValueField(.eventSourceUserData) == Autoscroller.syntheticMarker {
            return Unmanaged.passUnretained(event)
        }

        // Middle-click autoscroll (may consume button clicks).
        if Autoscroller.shared.handle(type: type, event: event) {
            return nil
        }

        guard type == .scrollWheel else {
            return Unmanaged.passUnretained(event)
        }

        var isWheel: Bool = true
        if !Settings.shared.alternateDetection {
            // scrollWheelEventIsContinuous will be 0 for mice and 1 for trackpads
            // probably faster than the alternate detection method since only one comparison
            if event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 {
                isWheel = false
            }
        } else {
            // Undocumented values but seem to be non-zero only for trackpads
            if event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0 ||
                event.getDoubleValueField(.scrollWheelEventScrollCount) != 0.0 ||
                event.getDoubleValueField(.scrollWheelEventScrollPhase) != 0.0 {
                isWheel = false
            }
        }

        if isWheel {
            // Invert the scroll event
            if Settings.shared.invertVertical {
                event.setIntegerValueField(
                    .scrollWheelEventDeltaAxis1, value: -event.getIntegerValueField(.scrollWheelEventDeltaAxis1))
            }
            if Settings.shared.invertHorizontal {
                event.setIntegerValueField(
                    .scrollWheelEventDeltaAxis2, value: -event.getIntegerValueField(.scrollWheelEventDeltaAxis2))
            }
            // Disable scroll acceleration
            if Settings.shared.fixedScrollDistance {
                event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: event.getIntegerValueField(.scrollWheelEventDeltaAxis1).signum() * Int64(Settings.shared.scrollLines))
            }
        }
        // pass the event to the system
        return Unmanaged.passUnretained(event)
    }

    // Intercept scroll wheel events
    func interceptScroll() {
        stateLock.lock()
        guard !isIntercepting else {
            stateLock.unlock()
            return
        }
        isIntercepting = true
        stateLock.unlock()

        registerForWakeNotifications()

        DispatchQueue.global(qos: .userInteractive).async {
            guard let eventTap = CGEvent.tapCreate(
                tap: .cghidEventTap,
                place: .tailAppendEventTap,
                options: .defaultTap,
                // Scroll wheel events, plus mouse button presses for middle-click autoscroll.
                // (No keyboard or mouse-movement events.)
                eventsOfInterest: ScrollInterceptor.eventMask,
                callback: self.scrollEventCallback,
                userInfo: nil
            ) else {
                // Tap creation can fail if accessibility permission was revoked.
                // Bail out cleanly instead of force-unwrapping and crashing.
                self.clearInterceptionState()
                return
            }

            guard let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0) else {
                CFMachPortInvalidate(eventTap)
                self.clearInterceptionState()
                return
            }

            let runLoop = CFRunLoopGetCurrent()
            self.stateLock.lock()
            self.eventTap = eventTap
            self.runLoopSource = runLoopSource
            self.runLoop = runLoop
            self.stateLock.unlock()

            CFRunLoopAddSource(runLoop, runLoopSource, CFRunLoopMode.commonModes)
            CGEvent.tapEnable(tap: eventTap, enable: true)
            CFRunLoopRun()

            // Reached only when the run loop is stopped (e.g. during a restart).
            CFRunLoopRemoveSource(runLoop, runLoopSource, CFRunLoopMode.commonModes)
            CFMachPortInvalidate(eventTap)
            self.clearInterceptionState()
        }
    }

    /// Re-enables the existing tap. Called from the tap callback when macOS
    /// disables it, and from the wake-from-sleep notification. If the tap can
    /// no longer be revived it is torn down and recreated.
    func reEnableTap() {
        stateLock.lock()
        let tap = eventTap
        stateLock.unlock()

        guard let tap = tap else {
            // No tap yet (or it was torn down) — (re)start interception.
            restart()
            return
        }

        if !CGEvent.tapIsEnabled(tap: tap) {
            CGEvent.tapEnable(tap: tap, enable: true)
        }

        // If it still won't enable, the tap was invalidated during standby;
        // rebuild it from scratch.
        if !CGEvent.tapIsEnabled(tap: tap) {
            restart()
        }
    }

    /// Tears down the current run loop (if any) and creates a fresh tap.
    private func restart() {
        stateLock.lock()
        let loop = runLoop
        stateLock.unlock()

        if let loop = loop {
            // Causes CFRunLoopRun() in interceptScroll() to return and clean up,
            // which resets isIntercepting so the relaunch below can proceed.
            CFRunLoopStop(loop)
        }

        DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 0.5) {
            self.interceptScroll()
        }
    }

    private func registerForWakeNotifications() {
        stateLock.lock()
        let alreadyRegistered = wakeObserver != nil
        stateLock.unlock()
        guard !alreadyRegistered else { return }

        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: nil
        ) { _ in
            // The HID subsystem can lag behind wake, so re-enable immediately
            // and again shortly after to cover the race.
            ScrollInterceptor.shared.reEnableTap()
            DispatchQueue.global(qos: .userInteractive).asyncAfter(deadline: .now() + 1.0) {
                ScrollInterceptor.shared.reEnableTap()
            }
        }

        stateLock.lock()
        wakeObserver = observer
        stateLock.unlock()
    }

    private func clearInterceptionState() {
        stateLock.lock()
        eventTap = nil
        runLoopSource = nil
        runLoop = nil
        isIntercepting = false
        stateLock.unlock()
    }
}
