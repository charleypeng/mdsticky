import SwiftUI
import AppKit

enum MarkdownToolbarAction {
    case inline(prefix: String, suffix: String, placeholder: String)
    case heading(level: Int)
    case block(prefix: String)
}

struct MarkdownToolbar: View {
    let onAction: (MarkdownToolbarAction) -> Void

    private let inlineActions: [(icon: String, label: String, action: MarkdownToolbarAction)] = [
        ("bold",          "加粗",   .inline(prefix: "**",  suffix: "**",    placeholder: "粗体文字")),
        ("italic",        "斜体",   .inline(prefix: "*",   suffix: "*",     placeholder: "斜体文字")),
        ("strikethrough", "删除线", .inline(prefix: "~~",  suffix: "~~",    placeholder: "删除线文字")),
        ("chevron.left.forwardslash.chevron.right", "代码", .inline(prefix: "`", suffix: "`", placeholder: "代码")),
        ("link",          "链接",   .inline(prefix: "[",   suffix: "](url)", placeholder: "链接文字")),
    ]

    private let blockActions: [(icon: String, label: String, action: MarkdownToolbarAction)] = [
        ("list.bullet", "无序列表", .block(prefix: "\n- ")),
        ("list.number", "有序列表", .block(prefix: "\n1. ")),
        ("checklist",   "复选框",   .block(prefix: "\n- [ ] ")),
        ("curlybraces", "代码块",   .block(prefix: "\n```\n\n```\n")),
        ("minus",       "分割线",   .block(prefix: "\n---\n")),
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
        .help("标题级别")
    }
}
