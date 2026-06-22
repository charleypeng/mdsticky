//
//  StickyNoteView.swift
//  mdsticky
//

import SwiftUI
import SwiftData
import AppKit
import MarkdownUI

struct StickyNoteView: View {
    @Bindable var note: StickyNote
    @Environment(\.modelContext) private var modelContext
    @StateObject private var settings = AppSettings.shared
    @State private var isEditing: Bool = false
    @State private var content: String = ""
    @State private var activeTextView: NSTextView?

    private let textColor = Color(white: 0.18)
    private let secondaryColor = Color(white: 0.38)
    private let buttonColor = Color(white: 0.15)

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
                        handleMarkdownAction(action)
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
        .id("sticky-\(settings.language)")
        .environment(\.locale, Locale(identifier: settings.language))
        .preferredColorScheme(settings.colorSchemeMode.resolved)
}

    private var titleBar: some View {
        HStack {
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
                        .font(.system(size: 12))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 22)
                .tint(buttonColor)

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
                MarkdownEditorView(
                    content: $content,
                    onTextViewReady: { tv in activeTextView = tv },
                    autoFocus: true,
                    textColor: NSColor(white: 0.18, alpha: 1.0)
                )
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

    private func handleMarkdownAction(_ action: MarkdownToolbarAction) {
        switch action {
        case .inline(let prefix, let suffix, let placeholder):
            insertAtCursor(prefix: prefix, suffix: suffix, placeholder: placeholder, selectPlaceholder: true)
        case .heading(let level):
            let hashes = String(repeating: "#", count: level)
            insertAtCursor(prefix: "\n\(hashes) ", suffix: "", placeholder: "", selectPlaceholder: false)
        case .block(let prefix):
            if prefix == "\n```\n\n```\n" {
                insertAtCursor(prefix: "\n```\n", suffix: "\n```\n", placeholder: "", selectPlaceholder: false)
            } else {
                insertAtCursor(prefix: prefix, suffix: "", placeholder: "", selectPlaceholder: false)
            }
        }
    }

    private func insertAtCursor(prefix: String, suffix: String, placeholder: String, selectPlaceholder: Bool) {
        guard let tv = activeTextView else {
            content += prefix + placeholder + suffix
            return
        }
        let selectedRange = tv.selectedRange()
        let nsText = tv.string as NSString
        if selectedRange.length > 0 {
            let selected = nsText.substring(with: selectedRange)
            tv.insertText(prefix + selected + suffix, replacementRange: selectedRange)
        } else {
            let safePos = min(selectedRange.location, nsText.length)
            tv.insertText(prefix + placeholder + suffix, replacementRange: NSRange(location: safePos, length: 0))
            if selectPlaceholder, !placeholder.isEmpty {
                let selectStart = safePos + (prefix as NSString).length
                tv.setSelectedRange(NSRange(location: selectStart, length: (placeholder as NSString).length))
                tv.scrollRangeToVisible(tv.selectedRange())
            }
        }
        // textDidChange will sync content -> save
    }
}

struct MarkdownContentView: View {
    let text: String
    let textColor: Color
    let secondaryColor: Color

    var body: some View {
        if text.isEmpty {
            Text(verbatim: tr("Double-click to edit…"))
                .font(.system(size: 13))
                .foregroundStyle(secondaryColor)
        } else {
            Markdown(text)
                .markdownTheme(.mdsticky(textColor: textColor))
        }
    }
}

extension Theme {
    static func mdsticky(textColor: Color) -> Theme {
        // Start from .gitHub so heading1...heading6 carry their default
        // font sizes. We then override .text to match the note's
        // 13pt base font and the caller-supplied text color.
        // Code (inline and block) is forced to dark-background / white-text
        // so it remains readable on any note color the user picks.
        Theme.gitHub
            .text {
                FontSize(13)
                ForegroundColor(textColor)
            }
            .code {
                FontFamilyVariant(.monospaced)
                FontSize(.em(0.85))
                ForegroundColor(.white)
                BackgroundColor(Color.black.opacity(0.55))
            }
            .codeBlock { configuration in
                ScrollView(.horizontal) {
                    configuration.label
                        .fixedSize(horizontal: false, vertical: true)
                        .relativeLineSpacing(.em(0.225))
                        .markdownTextStyle {
                            FontFamilyVariant(.monospaced)
                            FontSize(.em(0.85))
                            ForegroundColor(.white)
                        }
                        .padding(12)
                }
                .background(Color.black.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .markdownMargin(top: 0, bottom: 16)
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
