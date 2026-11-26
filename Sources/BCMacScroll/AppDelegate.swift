//
//  AppDelegate.swift
//  BC MacScroll
//

import AppKit
import SwiftUI
import Combine

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {

    private let settings = Settings.shared
    private let permissions = PermissionMonitor.shared

    private var statusItem: NSStatusItem?
    private let menu = NSMenu()
    private var statusMenuItem: NSMenuItem!
    private var enabledMenuItem: NSMenuItem!
    private var reverseMenuItem: NSMenuItem!
    private var autoscrollMenuItem: NSMenuItem!

    private var settingsWindow: NSWindow?
    private var welcomeWindow: NSWindow?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMenu()

        settings.$showMenuBarIcon
            .receive(on: RunLoop.main)
            .sink { [weak self] show in self?.setStatusItemVisible(show) }
            .store(in: &cancellables)

        settings.$enabled.combineLatest(settings.$disableMouseAccel)
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled, disableAccel in
                MouseAcceleration.apply(disable: enabled && disableAccel)
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)

        permissions.$trusted
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] trusted in
                if trusted { ScrollInterceptor.shared.interceptScroll() }
                self?.updateStatusIcon()
            }
            .store(in: &cancellables)

        permissions.startWatching()

        if !permissions.trusted {
            showWelcome()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        MouseAcceleration.apply(disable: false)
    }

    /// Opening the app again (e.g. from Applications) shows Settings, which is
    /// the way back in when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showSettings() }
        return true
    }

    // MARK: - Menu bar

    private func setStatusItemVisible(_ visible: Bool) {
        if visible, statusItem == nil {
            let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.menu = menu
            statusItem = item
            updateStatusIcon()
        } else if !visible, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        let active = settings.enabled && permissions.trusted
        let image = NSImage(systemSymbolName: active ? "computermouse.fill" : "computermouse",
                            accessibilityDescription: AppInfo.name)
        image?.isTemplate = true
        button.image = image
        button.appearsDisabled = !active
        button.toolTip = active ? "\(AppInfo.name) is active" : "\(AppInfo.name) is paused"
    }

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        statusMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        enabledMenuItem = addItem("Enabled", #selector(toggleEnabled))
        menu.addItem(.separator())
        reverseMenuItem = addItem("Reverse Wheel Scrolling", #selector(toggleReverse), symbol: "arrow.up.arrow.down")
        autoscrollMenuItem = addItem("Middle-Click Autoscroll", #selector(toggleAutoscroll),
                                     symbol: "arrow.up.and.down.and.arrow.left.and.right")
        menu.addItem(.separator())
        addItem("Settings…", #selector(openSettings), key: ",", symbol: "gearshape")
        addItem("About \(AppInfo.name)", #selector(showAbout), symbol: "info.circle")
        menu.addItem(.separator())
        addItem("Quit \(AppInfo.name)", #selector(quit), key: "q")
    }

    @discardableResult
    private func addItem(_ title: String, _ action: Selector, key: String = "", symbol: String? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        menu.addItem(item)
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let status: String
        if !permissions.trusted {
            status = "⚠︎ Needs Accessibility permission"
        } else {
            status = settings.enabled ? "\(AppInfo.name): Active" : "\(AppInfo.name): Paused"
        }
        statusMenuItem.title = status
        enabledMenuItem.state = settings.enabled ? .on : .off
        reverseMenuItem.state = settings.invertVertical ? .on : .off
        autoscrollMenuItem.state = settings.autoscrollEnabled ? .on : .off
        reverseMenuItem.isEnabled = settings.enabled
        autoscrollMenuItem.isEnabled = settings.enabled
    }

    @objc private func toggleEnabled() { settings.enabled.toggle() }
    @objc private func toggleReverse() { settings.invertVertical.toggle() }
    @objc private func toggleAutoscroll() { settings.autoscrollEnabled.toggle() }
    @objc private func openSettings() { showSettings() }
    @objc private func quit() { NSApp.terminate(nil) }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSAttributedString(
            string: "Free software under the GNU General Public License v3. Provided without any warranty.",
            attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: AppInfo.name,
            .credits: credits,
        ])
    }

    // MARK: - Windows

    func showSettings() {
        if settingsWindow == nil {
            let window = makeWindow(title: "\(AppInfo.name) Settings", content: SettingsView())
            settingsWindow = window
        }
        present(settingsWindow)
    }

    private func showWelcome() {
        if welcomeWindow == nil {
            let view = WelcomeView(
                onDone: { [weak self] in
                    self?.welcomeWindow?.close()
                    self?.showSettings()
                },
                onQuit: { NSApp.terminate(nil) })
            welcomeWindow = makeWindow(title: "Welcome", content: view)
        }
        present(welcomeWindow)
    }

    private func makeWindow<V: View>(title: String, content: V) -> NSWindow {
        let controller = NSHostingController(rootView: content)
        let window = NSWindow(contentViewController: controller)
        window.title = title
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }

    private func present(_ window: NSWindow?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
