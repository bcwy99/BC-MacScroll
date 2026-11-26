//
//  Permissions.swift
//  BC MacScroll
//
//  Tracks whether the app has Accessibility access, which macOS requires
//  before an app may modify scroll and mouse-button events.
//

import AppKit
import ApplicationServices

final class PermissionMonitor: ObservableObject {

    static let shared = PermissionMonitor()

    @Published var trusted: Bool = AXIsProcessTrusted()

    private var timer: Timer?

    /// Polls once a second until access is granted (macOS sends no notification for it).
    func startWatching() {
        guard timer == nil else { return }
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            let now = AXIsProcessTrusted()
            if self?.trusted != now { self?.trusted = now }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    /// Shows the system prompt and adds the app to the Accessibility list.
    func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
