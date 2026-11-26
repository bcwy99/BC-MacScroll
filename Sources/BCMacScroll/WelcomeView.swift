//
//  WelcomeView.swift
//  BC MacScroll
//
//  First-run window that walks the user through granting Accessibility access
//  and updates itself the moment access is granted.
//

import SwiftUI

struct WelcomeView: View {
    @ObservedObject var permissions = PermissionMonitor.shared
    var onDone: () -> Void = {}
    var onQuit: () -> Void = {}

    var body: some View {
        VStack(spacing: 18) {
            Image(nsImage: AppInfo.icon)
                .resizable()
                .frame(width: 88, height: 88)

            VStack(spacing: 6) {
                Text("Welcome to BC MacScroll")
                    .font(.title.weight(.semibold))
                Text("Classic mouse-wheel scrolling, natural trackpad scrolling, and middle-click autoscroll.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                StepRow(number: 1, text: "Click **Open Accessibility Settings** below.")
                StepRow(number: 2, text: "Turn on **BC MacScroll** in the list. Enter your password if asked.")
                StepRow(number: 3, text: "Come back here. This window updates by itself.")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )

            statusLine

            HStack {
                if permissions.trusted {
                    Spacer()
                    Button("Get Started", action: onDone)
                        .keyboardShortcut(.defaultAction)
                        .controlSize(.large)
                } else {
                    Button("Quit", action: onQuit)
                        .controlSize(.large)
                    Spacer()
                    Button("Open Accessibility Settings") {
                        permissions.requestAccess()
                        permissions.openAccessibilitySettings()
                    }
                    .keyboardShortcut(.defaultAction)
                    .controlSize(.large)
                }
            }

            Label("BC MacScroll only sees scroll-wheel and mouse-button events. It never sees your keyboard and never connects to the internet.",
                  systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(width: 460)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var statusLine: some View {
        if permissions.trusted {
            Label("Access granted. You're all set!", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(.headline)
        } else {
            Label("Waiting for permission…", systemImage: "hourglass")
                .foregroundStyle(.orange)
                .font(.headline)
        }
    }
}

private struct StepRow: View {
    let number: Int
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Color.accentColor))
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
