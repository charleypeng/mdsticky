//
//  mdstickyApp.swift
//  mdsticky
//

import SwiftUI
import SwiftData
import AppKit

private func enforceSingleInstance() {
    let bundleID = Bundle.main.bundleIdentifier ?? "charleypeng.mdsticky"
    let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
    if running.count > 1 {
        running.first?.activate(options: .activateIgnoringOtherApps)
        exit(0)
    }
}

@main
struct mdstickyApp: App {
    static var sharedContainer: ModelContainer!

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            StickyNote.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            mdstickyApp.sharedContainer = container
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        enforceSingleInstance()
    }

    @StateObject private var settings = AppSettings.shared
    @State private var hasRestored = false

    private func colorScheme(from mode: ColorSchemeMode) -> ColorScheme? {
        switch mode {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var body: some Scene {
        Window("便利贴管理", id: "manager") {
            ContentView()
                .frame(minWidth: 500, minHeight: 350)
                .preferredColorScheme(colorScheme(from: settings.colorSchemeMode))
                .onAppear {
                    if !hasRestored {
                        hasRestored = true
                        restoreVisibleNotes()
                        SyncServiceProvider.shared.startMonitoring()
                    }
                }
        }
        .modelContainer(sharedModelContainer)
        .defaultSize(width: 700, height: 500)
        .windowResizability(.contentSize)
        .environment(\.locale, Locale(identifier: settings.language))
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于 mdsticky") {
                    showAboutPanel()
                }
            }
            CommandGroup(after: .newItem) {
                Button("新建便利贴") {
                    newStickyNote()
                }
                .keyboardShortcut("n")
            }
        }

        MenuBarExtra("mdsticky", systemImage: "note.text") {
            MenuBarView()
                .frame(width: 220)
                .preferredColorScheme(colorScheme(from: settings.colorSchemeMode))
        }
        .modelContainer(sharedModelContainer)
        .environment(\.locale, Locale(identifier: settings.language))
    }

    private func restoreVisibleNotes() {
        let context = sharedModelContainer.mainContext
        let descriptor = FetchDescriptor<StickyNote>(predicate: #Predicate { $0.isVisible })
        guard let notes = try? context.fetch(descriptor) else { return }
        for note in notes {
            WindowManager.shared.showWindow(for: note, in: context)
        }
    }

    private func showAboutPanel() {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        let credits = NSAttributedString(string: "作者: charleypeng\nGitHub: https://github.com/charleypeng\n\n© 2026 charleypeng")
        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .applicationName: "mdsticky",
            .applicationVersion: "\(version) (\(build))",
            .credits: credits
        ])
    }

    private func newStickyNote() {
        let context = Self.sharedContainer.mainContext
        let now = Date()
        let fileName = NoteStorageService.generateFileName(date: now)
        let newNote = StickyNote(
            title: fileName.replacingOccurrences(of: ".md", with: ""),
            contentFileName: fileName,
            createdAt: now
        )
        context.insert(newNote)
        try? NoteStorageService.shared.save(content: "", for: newNote)
        try? context.save()
        WindowManager.shared.showWindow(for: newNote, in: context)
    }
}

struct MenuBarView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @StateObject private var syncProvider = SyncServiceProvider.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button("新建便利贴") {
                createNote()
                dismiss()
            }

            Button("管理便利贴") {
                openWindow(id: "manager")
                NSApp.activate(ignoringOtherApps: true)
                dismiss()
            }

            Divider()

            Button("立即同步") {
                Task { await SyncServiceProvider.shared.syncAll() }
                dismiss()
            }
            .disabled(SyncServiceProvider.shared.enabledConfigs.isEmpty)

            Divider()

            Button("退出") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
    }

    private func createNote() {
        let now = Date()
        let fileName = NoteStorageService.generateFileName(date: now)
        let newNote = StickyNote(
            title: fileName.replacingOccurrences(of: ".md", with: ""),
            contentFileName: fileName,
            createdAt: now
        )
        modelContext.insert(newNote)
        try? NoteStorageService.shared.save(content: "", for: newNote)
        try? modelContext.save()
        WindowManager.shared.showWindow(for: newNote, in: modelContext)
    }
}
