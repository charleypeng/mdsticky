//
//  ContentView.swift
//  mdsticky
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \StickyNote.createdAt, order: .reverse) private var notes: [StickyNote]
    @State private var selectedNote: StickyNote?
    @StateObject private var settings = AppSettings.shared

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedNote) {
                ForEach(notes) { note in
                    NavigationLink(value: note) {
                        NoteRowView(note: note)
                    }
                    .contextMenu {
                        Button(note.isVisible ? "Hide" : "Show") {
                            toggleVisibility(for: note)
                        }
                        Button(note.isPinned ? "Unpin" : "Pin") {
                            togglePin(for: note)
                        }
                        Divider()
                        Button("Delete", role: .destructive) {
                            delete(note: note)
                        }
                    }
                }
                .onDelete(perform: deleteNotes)
            }
            .navigationTitle("Sticky Notes")
            .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            .toolbar {
                ToolbarItem {
                    Button(action: addNote) {
                        Label("New Note", systemImage: "plus")
                    }
                }
                ToolbarItem {
                    Button(action: showSettings) {
                        Label("Settings", systemImage: "gear")
                    }
                }
            }
        } detail: {
            if let note = selectedNote {
                // .id(note.id) forces SwiftUI to destroy and rebuild the
                // view when the user picks a different row. Without this
                // the @State `content` carries the previous note's text
                // into the new view and onAppear only fires once.
                NoteDetailView(note: note)
                    .id(note.id)
            } else {
                Text("Select a Note")
                    .foregroundStyle(.secondary)
            }
        }
        .id("content-\(settings.language)")
        .environment(\.locale, Locale(identifier: settings.language))
    }

    private func addNote() {
        withAnimation {
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

    private func deleteNotes(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let note = notes[index]
                delete(note: note)
            }
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

struct NoteRowView: View {
    @Bindable var note: StickyNote

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: note.colorHex))
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.system(size: 13, weight: .medium))
                Text(note.createdAt, format: Date.FormatStyle(date: .numeric, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 4) {
                if note.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
                if note.isVisible {
                    Image(systemName: "eye")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
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
                Button(note.isVisible ? "Hide" : "Show") {
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
