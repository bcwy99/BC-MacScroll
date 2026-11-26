//
//  Settings.swift
//  BC MacScroll
//
//  All user preferences, persisted in UserDefaults and observable from SwiftUI.
//  Values are also read (without locking) from the event-tap thread; they are
//  plain Bool/Int/Double so a stale read only ever affects a single event.
//

import Foundation
import ServiceManagement

final class Settings: ObservableObject {

    static let shared = Settings()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let enabled = "Enabled"
        static let invertVertical = "InvertVerticalScroll"
        static let invertHorizontal = "InvertHorizontalScroll"
        static let fixedScrollDistance = "DisableScrollAccel"
        static let scrollLines = "ScrollLines"
        static let alternateDetection = "AlternateDetectionMethod"
        static let disableMouseAccel = "DisableMouseAccel"
        static let showMenuBarIcon = "ShowMenuBarIcon"
        static let autoscrollEnabled = "MiddleClickAutoscroll"
        static let autoscrollSpeed = "AutoscrollSpeed"
    }

    /// Master switch. When off, every event passes through untouched.
    @Published var enabled: Bool { didSet { defaults.set(enabled, forKey: Key.enabled) } }
    @Published var invertVertical: Bool { didSet { defaults.set(invertVertical, forKey: Key.invertVertical) } }
    @Published var invertHorizontal: Bool { didSet { defaults.set(invertHorizontal, forKey: Key.invertHorizontal) } }
    /// Every wheel notch scrolls exactly `scrollLines` lines (no acceleration).
    @Published var fixedScrollDistance: Bool { didSet { defaults.set(fixedScrollDistance, forKey: Key.fixedScrollDistance) } }
    @Published var scrollLines: Int { didSet { defaults.set(scrollLines, forKey: Key.scrollLines) } }
    @Published var alternateDetection: Bool { didSet { defaults.set(alternateDetection, forKey: Key.alternateDetection) } }
    @Published var disableMouseAccel: Bool { didSet { defaults.set(disableMouseAccel, forKey: Key.disableMouseAccel) } }
    @Published var showMenuBarIcon: Bool { didSet { defaults.set(showMenuBarIcon, forKey: Key.showMenuBarIcon) } }
    @Published var autoscrollEnabled: Bool { didSet { defaults.set(autoscrollEnabled, forKey: Key.autoscrollEnabled) } }
    /// Autoscroll speed multiplier, 0.25 ... 3.0.
    @Published var autoscrollSpeed: Double { didSet { defaults.set(autoscrollSpeed, forKey: Key.autoscrollSpeed) } }

    /// Backed by the system's login-item registry rather than UserDefaults.
    @Published var launchAtLogin: Bool {
        didSet {
            guard launchAtLogin != oldValue, !syncingLoginItem else { return }
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("BC MacScroll: could not change login item: \(error)")
                syncingLoginItem = true
                launchAtLogin = SMAppService.mainApp.status == .enabled
                syncingLoginItem = false
            }
        }
    }
    private var syncingLoginItem = false

    private init() {
        defaults.register(defaults: [
            Key.enabled: true,
            Key.invertVertical: true,
            Key.invertHorizontal: false,
            Key.fixedScrollDistance: true,
            Key.scrollLines: 3,
            Key.alternateDetection: false,
            Key.disableMouseAccel: false,
            Key.showMenuBarIcon: true,
            Key.autoscrollEnabled: true,
            Key.autoscrollSpeed: 1.0,
        ])
        enabled = defaults.bool(forKey: Key.enabled)
        invertVertical = defaults.bool(forKey: Key.invertVertical)
        invertHorizontal = defaults.bool(forKey: Key.invertHorizontal)
        fixedScrollDistance = defaults.bool(forKey: Key.fixedScrollDistance)
        scrollLines = min(max(defaults.integer(forKey: Key.scrollLines), 1), 20)
        alternateDetection = defaults.bool(forKey: Key.alternateDetection)
        disableMouseAccel = defaults.bool(forKey: Key.disableMouseAccel)
        showMenuBarIcon = defaults.bool(forKey: Key.showMenuBarIcon)
        autoscrollEnabled = defaults.bool(forKey: Key.autoscrollEnabled)
        autoscrollSpeed = min(max(defaults.double(forKey: Key.autoscrollSpeed), 0.25), 3.0)
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
