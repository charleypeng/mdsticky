import SwiftUI
import AppKit

enum MarkdownToolbarAction {
    case inline(prefix: String, suffix: String, placeholder: String)
    case heading(level: Int)
    case block(prefix: String)
}

struct MarkdownToolbar: View {
    let onAction: (MarkdownToolbarAction) -> Void

    private let inlineActions: [(icon: String, label: LocalizedStringKey, action: MarkdownToolbarAction)] = [
        ("bold",          "Bold",   .inline(prefix: "**",  suffix: "**",    placeholder: "bold text")),
        ("italic",        "Italic",   .inline(prefix: "*",   suffix: "*",     placeholder: "italic text")),
        ("strikethrough", "Strikethrough", .inline(prefix: "~~",  suffix: "~~",    placeholder: "strikethrough text")),
        ("chevron.left.forwardslash.chevron.right", "Code", .inline(prefix: "`", suffix: "`", placeholder: "代码")),
        ("link",          "Link",   .inline(prefix: "[",   suffix: "](url)", placeholder: "link text")),
    ]

    private let blockActions: [(icon: String, label: LocalizedStringKey, action: MarkdownToolbarAction)] = [
        ("list.bullet", "Bullet List", .block(prefix: "\n- ")),
        ("list.number", "Numbered List", .block(prefix: "\n1. ")),
        ("checklist",   "Checklist",   .block(prefix: "\n- [ ] ")),
        ("curlybraces", "Code Block",   .block(prefix: "\n```\n\n```\n")),
        ("minus",       "Divider",   .block(prefix: "\n---\n")),
    ]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                headingDropdown

                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)

                ForEach(inlineActions.indices, id: \.self) { index in
                    let entry = inlineActions[index]
                    Button {
                        onAction(entry.action)
                    } label: {
                        Image(systemName: entry.icon)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 24, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(white: 0.15))
                    .help(entry.label)
                }

                Divider()
                    .frame(height: 16)
                    .padding(.horizontal, 4)

                ForEach(blockActions.indices, id: \.self) { index in
                    let entry = blockActions[index]
                    Button {
                        onAction(entry.action)
                    } label: {
                        Image(systemName: entry.icon)
                            .font(.system(size: 12, weight: .medium))
                            .frame(width: 24, height: 22)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(white: 0.15))
                    .help(entry.label)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 26)
        .background(Color.black.opacity(0.08))
        .overlay(Rectangle().frame(height: 1).foregroundStyle(Color.black.opacity(0.06)), alignment: .bottom)
    }

    private var headingDropdown: some View {
        Menu {
            ForEach(1...6, id: \.self) { level in
                Button {
                    onAction(.heading(level: level))
                } label: {
                    Text("H\(level)")
                        .foregroundStyle(Color(white: 0.15))
                }
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "textformat.size")
                    .font(.system(size: 11, weight: .medium))
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .frame(width: 30, height: 22)
            .foregroundStyle(Color(white: 0.15))
        }
        .menuStyle(.borderlessButton)
        .frame(width: 30)
        .contentShape(Rectangle())
        // macOS's Menu rendering ignores foregroundStyle on the label and
        // falls back to the system accent color (usually blue). Tint forces
        // it to match the rest of the toolbar's dark gray.
        .tint(Color(white: 0.15))
        .help("Heading Level")
    }
}
