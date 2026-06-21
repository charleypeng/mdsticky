//
//  StickyNoteView.swift
//  mdsticky
//
//  Single sticky note floating window content with Markdown support.
//

import SwiftUI
import SwiftData
import AppKit

struct StickyNoteView: View {
    @Bindable var note: StickyNote
    @Environment(\.modelContext) private var modelContext
    @State private var isEditing: Bool = false
    @State private var content: String = ""

    private let textColor = Color(white: 0.18)
    private let secondaryColor = Color(white: 0.38)
    private let buttonColor = Color(white: 0.18)

    var body: some View {
        ZStack {
            Color(hex: note.colorHex)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                titleBar
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)

                if isEditing {
                    MarkdownToolbar { action in
                        performMarkdownAction(action, content: &content)
                    }
                }

                contentArea
                    .padding(.horizontal, 10)
                    .padding(.bottom, 10)
            }
        }
        .onAppear {
            content = (try? NoteStorageService.shared.load(for: note)) ?? ""
        }
        .onChange(of: content) { _, newValue in
            try? NoteStorageService.shared.save(content: newValue, for: note)
            try? modelContext.save()
        }
    }

    private var titleBar: some View {
        HStack {
            Text(note.title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(textColor)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 6) {
                Button(action: togglePin) {
                    Image(systemName: note.isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(note.isPinned ? .blue : buttonColor)

                Menu {
                    ForEach(NoteColor.allCases, id: \.self) { noteColor in
                        Button(action: { changeColor(to: noteColor) }) {
                            HStack {
                                Circle()
                                    .fill(noteColor.swiftUIColor)
                                    .frame(width: 14, height: 14)
                                Text(noteColor.name)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "paintpalette")
                        .font(.system(size: 11))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
                .foregroundStyle(buttonColor)

                Button(action: toggleEdit) {
                    Image(systemName: isEditing ? "eye" : "pencil")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundStyle(buttonColor)

                Button(action: close) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(buttonColor)
            }
        }
    }

    private var contentArea: some View {
        Group {
            if isEditing {
                TextEditor(text: $content)
                    .font(.system(size: 13))
                    .foregroundStyle(textColor)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
            } else {
                ScrollView {
                    MarkdownContentView(text: content, textColor: textColor, secondaryColor: secondaryColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onTapGesture(count: 2) {
            isEditing.toggle()
        }
    }

    private func togglePin() {
        note.isPinned.toggle()
        WindowManager.shared.updatePinState(for: note)
        try? modelContext.save()
    }

    private func changeColor(to noteColor: NoteColor) {
        note.colorHex = noteColor.rawValue
        WindowManager.shared.updateColor(for: note)
        try? modelContext.save()
    }

    private func toggleEdit() {
        isEditing.toggle()
    }

    private func close() {
        WindowManager.shared.hideWindow(for: note, in: modelContext)
    }
}

struct MarkdownContentView: View {
    let text: String
    let textColor: Color
    let secondaryColor: Color

    var body: some View {
        if text.isEmpty {
            Text("双击编辑...")
                .font(.system(size: 13))
                .foregroundStyle(secondaryColor)
        } else if let attrString = try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(
                allowsExtendedAttributes: true,
                interpretedSyntax: .full,
                failurePolicy: .returnPartiallyParsedIfPossible
            )
        ) {
            Text(attrString)
                .font(.system(size: 13))
                .foregroundStyle(textColor)
        } else {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(textColor)
        }
    }
}

#Preview {
    let note = StickyNote(
        title: "2026-06-21 16.00",
        contentFileName: "2026-06-21 16.00.md",
        colorHex: NoteColor.yellow.rawValue
    )
    StickyNoteView(note: note)
        .frame(width: 300, height: 220)
        .modelContainer(for: StickyNote.self, inMemory: true)
}
