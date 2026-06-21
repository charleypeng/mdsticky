//
//  MarkdownEditorView.swift
//  mdsticky
//
//  NSViewRepresentable wrapping NSScrollView + NSTextView for the
//  sticky-note Markdown editor. Pure input component — knows nothing
//  about Note, storage, or Markdown syntax.
//

import SwiftUI
import AppKit

struct MarkdownEditorView: NSViewRepresentable {
    @Binding var content: String
    var onTextViewReady: (NSTextView) -> Void
    var autoFocus: Bool
    var textColor: NSColor

    func makeCoordinator() -> Coordinator {
        Coordinator(content: $content)
    }

    func makeNSView(context: Context) -> NSView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        let textView = NSTextView()
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = NSFont.systemFont(ofSize: 13)
        textView.textColor = textColor
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.delegate = context.coordinator
        textView.string = content

        scrollView.documentView = textView
        onTextViewReady(textView)

        if autoFocus {
            DispatchQueue.main.async { [weak textView] in
                guard let tv = textView else { return }
                tv.window?.makeFirstResponder(tv)
            }
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        // Intentionally a no-op. The NSTextView is the single source of truth;
        // Coordinator pushes NSTextView -> content (one-way).
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var content: Binding<String>

        init(content: Binding<String>) {
            self.content = content
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView else { return }
            content.wrappedValue = tv.string
        }
    }
}
