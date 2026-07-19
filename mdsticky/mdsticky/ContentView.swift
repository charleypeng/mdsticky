//
//  ContentView.swift
//  mdsticky
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StickyNote.createdAt, order: .reverse) private var notes: [StickyNote]
    @State private var selectedNoteIds: Set<StickyNote.ID> = []
    @State private var confirmDeleteNotes: [StickyNote] = []
    @StateObject private var settings = AppSettings.shared

    private var selectedNotes: [StickyNote] {
        notes.filter { selectedNoteIds.contains($0.id) }
    }

    var body: some View {
        NavigationSplitView {
            NoteTableView(
                notes: notes,
                selectedIds: $selectedNoteIds,
                onDoubleClickNote: { note in
                    WindowManager.shared.showWindow(for: note, in: modelContext)
                },
                onDeleteNotes: { notes in
                    confirmDeleteNotes = notes
                },
                onToggleVisibility: { toggleVisibility(for: $0) },
                onTogglePin: { togglePin(for: $0) }
            )
            .navigationTitle(tr("Sticky Notes"))
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            .toolbar {
                ToolbarItem {
                    Button(action: addNote) {
                        Label(tr("New Note"), systemImage: "plus")
                    }
                }
                ToolbarItem {
                    Button(action: showSettings) {
                        Label(tr("Settings"), systemImage: "gear")
                    }
                }
            }
            .onDeleteCommand {
                guard !selectedNoteIds.isEmpty else { return }
                confirmDeleteNotes = selectedNotes
            }
        } detail: {
            if let note = selectedNoteIds.first.flatMap({ id in notes.first(where: { $0.id == id }) }) {
                NoteDetailView(note: note)
                    .id(note.id)
            } else {
                Text(verbatim: tr("Select a Note"))
                    .foregroundStyle(.secondary)
            }
        }
        .id("content-\(settings.language)")
        .environment(\.locale, Locale(identifier: settings.language))
        .confirmationDialog(tr("Confirm Delete"), isPresented: .init(
            get: { !confirmDeleteNotes.isEmpty },
            set: { if !$0 { confirmDeleteNotes = [] } }
        )) {
            Button(tr("Delete"), role: .destructive) {
                let targets = confirmDeleteNotes
                confirmDeleteNotes = []
                for note in targets { delete(note: note) }
            }
            Button(tr("Cancel"), role: .cancel) { confirmDeleteNotes = [] }
        } message: {
            Text(verbatim: confirmDeleteNotes.count == 1
                ? String(format: tr("Are you sure you want to delete the sync service \"%@\"? This action cannot be undone.").replacingOccurrences(of: "sync service", with: "note"), confirmDeleteNotes.first?.title ?? "")
                : String(format: tr("Delete %ld notes?"), confirmDeleteNotes.count))
        }
    }

    private func addNote() {
        withAnimation {
            let now = Date()
            let fileName = NoteStorageService.uniqueFileName(date: now)
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

    private func delete(note: StickyNote) {
        WindowManager.shared.deleteWindow(for: note, in: modelContext)
    }

    private func toggleVisibility(for note: StickyNote) {
        if note.isVisible {
            WindowManager.shared.hideWindow(for: note, in: modelContext)
        } else {
            WindowManager.shared.showWindow(for: note, in: modelContext)
        }
    }

    private func togglePin(for note: StickyNote) {
        note.isPinned.toggle()
        WindowManager.shared.updatePinState(for: note)
        try? modelContext.save()
    }

    private func showSettings() {
        SettingsWindowController.shared.show()
    }
}

struct NoteDetailView: View {
    @Bindable var note: StickyNote
    @Environment(\.modelContext) private var modelContext
    @State private var content: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(note.title)
                    .font(.title2)
                Spacer()
                Button(note.isVisible ? tr("Hide") : tr("Show")) {
                    toggleVisibility()
                }
            }

            // The management window is preview-only. To edit, the user
            // opens the floating note window (or double-clicks a row in
            // the sidebar, which already shows the floating window).
            ScrollView {
                MarkdownContentView(
                    text: content,
                    textColor: .primary,
                    secondaryColor: .secondary
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
            }
        }
        .padding()
        .onAppear {
            content = (try? NoteStorageService.shared.load(for: note)) ?? ""
        }
    }

    private func toggleVisibility() {
        if note.isVisible {
            WindowManager.shared.hideWindow(for: note, in: modelContext)
        } else {
            WindowManager.shared.showWindow(for: note, in: modelContext)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: StickyNote.self, inMemory: true)
}
