import SwiftUI
import SwiftData
import AppKit

@MainActor
final class ManagerWindowController {
    static let shared = ManagerWindowController()
    private var window: NSWindow?
    private var container: ModelContainer { mdstickyApp.sharedContainer }

    private init() {}

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(
            rootView: ContentView()
                .frame(minWidth: 500, minHeight: 350)
                .environment(\.modelContext, container.mainContext)
        )
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = tr("Sticky Notes")
        window.center()
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        self.window = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
