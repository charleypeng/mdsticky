//
//  MarkdownToolbar.swift
//  mdsticky
//
//  Horizontal toolbar for inserting markdown syntax.
//

import SwiftUI
import AppKit

struct MarkdownToolbarAction {
    let icon: String
    let label: String
    let prefix: String
    let suffix: String
    let placeholder: String
}

struct MarkdownToolbar: View {
    let onAction: (MarkdownToolbarAction) -> Void

    private let actions: [MarkdownToolbarAction] = [
        MarkdownToolbarAction(icon: "bold",          label: "加粗",   prefix: "**",  suffix: "**",        placeholder: "粗体文字"),
        MarkdownToolbarAction(icon: "italic",        label: "斜体",   prefix: "*",   suffix: "*",         placeholder: "斜体文字"),
        MarkdownToolbarAction(icon: "strikethrough", label: "删除线", prefix: "~~",  suffix: "~~",        placeholder: "删除线文字"),
        MarkdownToolbarAction(icon: "h.square",      label: "标题",   prefix: "\n# ", suffix: "",          placeholder: "标题"),
        MarkdownToolbarAction(icon: "list.bullet",   label: "无序列表", prefix: "\n- ", suffix: "",        placeholder: "列表项"),
        MarkdownToolbarAction(icon: "list.number",   label: "有序列表", prefix: "\n1. ", suffix: "",       placeholder: "列表项"),
        MarkdownToolbarAction(icon: "checklist",     label: "复选框", prefix: "\n- [ ] ", suffix: "",    placeholder: "任务"),
        MarkdownToolbarAction(icon: "link",          label: "链接",   prefix: "[",   suffix: "](url)",    placeholder: "链接文字"),
        MarkdownToolbarAction(icon: "chevron.left.forwardslash.chevron.right", label: "代码", prefix: "`", suffix: "`", placeholder: "代码"),
        MarkdownToolbarAction(icon: "curlybraces",   label: "代码块",  prefix: "\n```\n", suffix: "\n```\n", placeholder: "代码块"),
        MarkdownToolbarAction(icon: "minus",         label: "分割线", prefix: "\n---\n", suffix: "",      placeholder: ""),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(actions.indices, id: \.self) { index in
                    let action = actions[index]
                    Button {
                        onAction(action)
                    } label: {
                        Image(systemName: action.icon)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 24, height: 22)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(white: 0.15))
                    .help(action.label)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 26)
        .background(Color.black.opacity(0.08))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.black.opacity(0.06)), alignment: .bottom)
    }
}

func performMarkdownAction(_ action: MarkdownToolbarAction, content: inout String) {
    guard let textView = findActiveTextView() else {
        content += action.prefix + action.placeholder + action.suffix
        return
    }

    let selectedRange = textView.selectedRange()
    let text = textView.string

    if selectedRange.length > 0 {
        let selectedText = (text as NSString).substring(with: selectedRange)
        let replacement = action.prefix + selectedText + action.suffix
        textView.insertText(replacement, replacementRange: selectedRange)
        content = textView.string
    } else {
        let insertion = action.prefix + action.placeholder + action.suffix
        let safePosition = min(selectedRange.location, (text as NSString).length)
        textView.insertText(insertion, replacementRange: NSRange(location: safePosition, length: 0))
        let selectStart = safePosition + action.prefix.count
        textView.setSelectedRange(NSRange(location: selectStart, length: action.placeholder.count))
        textView.scrollRangeToVisible(NSRange(location: selectStart, length: action.placeholder.count))
        content = textView.string
    }
}

private func findActiveTextView() -> NSTextView? {
    // Try first responder of key window first
    if let tv = NSApp.keyWindow?.firstResponder as? NSTextView, tv.isEditable, tv.isSelectable {
        return tv
    }
    // Fall back to recursive search through all windows
    for window in NSApp.windows {
        if let tv = findTextView(in: window.contentView) {
            return tv
        }
    }
    return nil
}

private func findTextView(in view: NSView?) -> NSTextView? {
    guard let view else { return nil }
    if let tv = view as? NSTextView, tv.isEditable, tv.isSelectable {
        return tv
    }
    for subview in view.subviews {
        if let found = findTextView(in: subview) {
            return found
        }
    }
    return nil
}
