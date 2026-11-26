//
//  main.swift
//  BC MacScroll
//

import AppKit

let app = NSApplication.shared

// `BCMacScroll --render-docs <folder>` renders the README screenshots and exits.
if let i = CommandLine.arguments.firstIndex(of: "--render-docs"), i + 1 < CommandLine.arguments.count {
    app.setActivationPolicy(.prohibited)
    DocsRenderer.render(to: URL(fileURLWithPath: CommandLine.arguments[i + 1]))
    exit(0)
}

let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
