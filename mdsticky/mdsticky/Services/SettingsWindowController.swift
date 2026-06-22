//
//  SettingsWindowController.swift
//  mdsticky
//
//  Manages the settings window via AppKit so it can be opened from anywhere.
//

import SwiftUI
import AppKit

@MainActor
final class SettingsWindowController {
    static let shared = SettingsWindowController()

    private var window: NSWindow?

    private init() {}

    func show() {
        if let window {
            centerWindow(window)
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: SettingsView())
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        self.window = window
        centerWindow(window)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func centerWindow(_ window: NSWindow) {
        guard let screen = window.screen ?? NSScreen.main else { return }
        let sf = screen.visibleFrame
        let wf = window.frame
        let x = sf.origin.x + (sf.width - wf.width) / 2
        let y = sf.origin.y + (sf.height - wf.height) / 2
        window.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
