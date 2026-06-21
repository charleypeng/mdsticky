//
//  WindowManager.swift
//  mdsticky
//
//  Manages floating NSWindows for each sticky note.
//

import SwiftUI
import SwiftData
import AppKit

@MainActor
final class WindowManager {
    static let shared = WindowManager()

    private var windows: [UUID: NSWindow] = [:]
    private var delegates: [UUID: StickyNoteWindowDelegate] = [:]

    private init() {}

    func showWindow(for note: StickyNote, in modelContext: ModelContext) {
        if let existing = windows[note.id] {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        note.isVisible = true
        try? modelContext.save()

        let delegate = StickyNoteWindowDelegate(note: note, modelContext: modelContext)
        delegates[note.id] = delegate

        let window = createWindow(for: note, delegate: delegate)
        windows[note.id] = window
        window.makeKeyAndOrderFront(nil)
    }

    func closeWindow(for note: StickyNote) {
        windows[note.id]?.orderOut(nil)
        windows.removeValue(forKey: note.id)
        delegates.removeValue(forKey: note.id)
    }

    func hideWindow(for note: StickyNote, in modelContext: ModelContext) {
        closeWindow(for: note)
        note.isVisible = false
        try? modelContext.save()
    }

    func deleteWindow(for note: StickyNote, in modelContext: ModelContext) {
        closeWindow(for: note)
        try? NoteStorageService.shared.delete(for: note)
        modelContext.delete(note)
        try? modelContext.save()
    }

    func updatePinState(for note: StickyNote) {
        guard let window = windows[note.id] else { return }
        window.level = note.isPinned ? .floating : .normal
        window.orderFront(nil)
    }

    func updateColor(for note: StickyNote) {
        guard let window = windows[note.id] else { return }
        window.backgroundColor = NSColor(hex: note.colorHex)
    }

    func updateTitle(for note: StickyNote) {
        windows[note.id]?.title = note.title
    }

    private func createWindow(for note: StickyNote, delegate: StickyNoteWindowDelegate) -> NSWindow {
        let contentView = StickyNoteView(note: note)
            .environment(\.modelContext, delegate.modelContext)
            .frame(minWidth: 180, minHeight: 140)

        let hostingView = NSHostingView(rootView: contentView)
        let frame = NSRect(
            x: note.positionX,
            y: note.positionY,
            width: note.width,
            height: note.height
        )

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = note.title
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.level = note.isPinned ? .floating : .normal
        window.backgroundColor = NSColor(hex: note.colorHex)
        window.contentView = hostingView
        window.delegate = delegate
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        return window
    }
}

@MainActor
final class StickyNoteWindowDelegate: NSObject, NSWindowDelegate {
    let note: StickyNote
    let modelContext: ModelContext

    init(note: StickyNote, modelContext: ModelContext) {
        self.note = note
        self.modelContext = modelContext
        super.init()
    }

    func windowDidMove(_ notification: Notification) {
        guard let frame = (notification.object as? NSWindow)?.frame else { return }
        note.positionX = frame.origin.x
        note.positionY = frame.origin.y
        try? modelContext.save()
    }

    func windowDidResize(_ notification: Notification) {
        guard let frame = (notification.object as? NSWindow)?.frame else { return }
        note.width = frame.size.width
        note.height = frame.size.height
        try? modelContext.save()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        WindowManager.shared.hideWindow(for: note, in: modelContext)
        return false
    }

    func windowWillClose(_ notification: Notification) {
        WindowManager.shared.closeWindow(for: note)
    }
}
