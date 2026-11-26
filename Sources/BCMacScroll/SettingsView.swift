//
//  SettingsView.swift
//  BC MacScroll
//

import SwiftUI
import AppKit

enum AppInfo {
    static let name = "BC MacScroll"
    static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }
    static let repoURL = URL(string: "https://github.com/bcwy99/BC-MacScroll")!
    static var icon: NSImage { NSApp?.applicationIconImage ?? NSImage(named: NSImage.applicationIconName)! }
}

struct SettingsView: View {
    @ObservedObject var settings = Settings.shared
    @ObservedObject var permissions = PermissionMonitor.shared
    /// The docs renderer turns scrolling off so the whole page is captured.
    var scrollable = true

    var body: some View {
        if scrollable {
            ScrollView { content }
                .frame(width: 520, height: 640)
                .background(Color(nsColor: .windowBackgroundColor))
        } else {
            content
                .frame(width: 520)
                .background(Color(nsColor: .windowBackgroundColor))
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if !permissions.trusted {
                PermissionBanner()
            }

            SettingsCard(title: "Scroll Wheel", symbol: "computermouse") {
                ToggleRow(title: "Reverse wheel scrolling",
                          detail: "Mouse wheel scrolls the classic way. Your trackpad keeps natural scrolling.",
                          isOn: $settings.invertVertical)
                Divider()
                ToggleRow(title: "Reverse horizontal scrolling",
                          detail: "For tilt wheels and side-scroll wheels.",
                          isOn: $settings.invertHorizontal)
                Divider()
                ToggleRow(title: "Fixed scroll distance",
                          detail: "Turns off wheel acceleration so every notch moves the same amount.",
                          isOn: $settings.fixedScrollDistance)
                if settings.fixedScrollDistance {
                    HStack {
                        Text("Lines per notch")
                            .padding(.leading, 16)
                        Spacer()
                        Text("\(settings.scrollLines)")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                        Stepper("", value: $settings.scrollLines, in: 1...20)
                            .labelsHidden()
                    }
                }
            }

            SettingsCard(title: "Middle-Click Autoscroll", symbol: "arrow.up.and.down.and.arrow.left.and.right") {
                ToggleRow(title: "Enable autoscroll",
                          detail: "Click the scroll wheel, then move the mouse to scroll. Click again to stop.",
                          isOn: $settings.autoscrollEnabled)
                Divider()
                HStack(spacing: 10) {
                    Text("Speed")
                    Image(systemName: "tortoise")
                        .foregroundStyle(.secondary)
                    Slider(value: $settings.autoscrollSpeed, in: 0.25...3.0)
                    Image(systemName: "hare")
                        .foregroundStyle(.secondary)
                }
                .disabled(!settings.autoscrollEnabled)
                .opacity(settings.autoscrollEnabled ? 1 : 0.5)
                TipText("Hold the wheel down and drag for quick scrolls; release to stop. "
                        + "While autoscroll is on, middle-click no longer opens links in new tabs.")
            }

            SettingsCard(title: "Pointer", symbol: "cursorarrow.motionlines") {
                ToggleRow(title: "Disable mouse acceleration",
                          detail: "Pointer moves the same distance however fast you move the mouse. Restored when you quit.",
                          isOn: $settings.disableMouseAccel)
            }

            SettingsCard(title: "General", symbol: "gearshape") {
                ToggleRow(title: "Launch at login",
                          detail: nil,
                          isOn: $settings.launchAtLogin)
                Divider()
                ToggleRow(title: "Show in menu bar",
                          detail: "If hidden, open BC MacScroll again from Applications to see this window.",
                          isOn: $settings.showMenuBarIcon)
            }

            SettingsCard(title: "Advanced", symbol: "wrench.and.screwdriver") {
                ToggleRow(title: "Alternate trackpad detection",
                          detail: "Try this if your mouse is mistaken for a trackpad (some Logitech mice and drivers).",
                          isOn: $settings.alternateDetection)
            }

            footer
        }
        .padding(22)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: AppInfo.icon)
                .resizable()
                .frame(width: 60, height: 60)
            VStack(alignment: .leading, spacing: 4) {
                Text(AppInfo.name)
                    .font(.title2.weight(.semibold))
                StatusPill(state: statusState)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Toggle("", isOn: $settings.enabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                Text(settings.enabled ? "On" : "Paused")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusState: StatusPill.State {
        if !permissions.trusted { return .needsPermission }
        return settings.enabled ? .active : .paused
    }

    private var footer: some View {
        HStack {
            Text("Version \(AppInfo.version)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Link("Help & Source", destination: AppInfo.repoURL)
                .font(.caption)
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Building blocks

struct SettingsCard<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 0.5)
            )
        }
    }
}

struct ToggleRow: View {
    let title: String
    let detail: String?
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }
}

struct TipText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lightbulb")
                .foregroundStyle(.yellow)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }
}

struct StatusPill: View {
    enum State { case active, paused, needsPermission }
    let state: State

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.15)))
        .foregroundStyle(color)
    }

    private var label: String {
        switch state {
        case .active: return "Active"
        case .paused: return "Paused"
        case .needsPermission: return "Needs permission"
        }
    }

    private var color: Color {
        switch state {
        case .active: return .green
        case .paused: return .secondary
        case .needsPermission: return .orange
        }
    }
}

struct PermissionBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility access needed")
                    .font(.headline)
                Text("BC MacScroll can't change scrolling until you allow it in System Settings.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Open Settings") {
                PermissionMonitor.shared.requestAccess()
                PermissionMonitor.shared.openAccessibilitySettings()
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
    }
}
