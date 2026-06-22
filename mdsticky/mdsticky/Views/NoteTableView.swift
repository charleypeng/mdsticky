import SwiftUI
import AppKit

struct NoteTableView: NSViewRepresentable {
    let notes: [StickyNote]
    @Binding var selectedIds: Set<StickyNote.ID>
    var onDoubleClickNote: (StickyNote) -> Void
    var onDeleteNotes: ([StickyNote]) -> Void
    var onToggleVisibility: (StickyNote) -> Void
    var onTogglePin: (StickyNote) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            selectedIds: $selectedIds,
            onDoubleClickNote: onDoubleClickNote,
            onDeleteNotes: onDeleteNotes,
            onToggleVisibility: onToggleVisibility,
            onTogglePin: onTogglePin
        )
    }

    func makeNSView(context: Context) -> NSScrollView {
        let tableView = NSTableView()
        tableView.columnAutoresizingStyle = .uniformColumnAutoresizingStyle
        tableView.allowsMultipleSelection = true
        tableView.allowsEmptySelection = true
        tableView.selectionHighlightStyle = .regular
        tableView.intercellSpacing = NSSize(width: 0, height: 1)
        tableView.rowHeight = 36
        tableView.floatsGroupRows = false
        tableView.headerView = nil
        tableView.focusRingType = .none
        tableView.menu = NSMenu()

        let col = NSTableColumn(identifier: .noteRow)
        col.isEditable = false
        tableView.addTableColumn(col)

        let scrollView = NSScrollView()
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false

        tableView.dataSource = context.coordinator
        tableView.delegate = context.coordinator
        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.doubleClickRow)

        context.coordinator.tableView = tableView
        context.coordinator.notes = notes

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let tableView = nsView.documentView as? NSTableView else { return }
        context.coordinator.notes = notes
        context.coordinator.selectedIds = $selectedIds
        context.coordinator.onDoubleClickNote = onDoubleClickNote
        context.coordinator.onDeleteNotes = onDeleteNotes
        context.coordinator.onToggleVisibility = onToggleVisibility
        context.coordinator.onTogglePin = onTogglePin

        tableView.reloadData()

        let idxs = notes.indices.filter { i in selectedIds.contains(notes[i].id) }
        tableView.selectRowIndexes(IndexSet(idxs), byExtendingSelection: false)
    }
}

extension NSUserInterfaceItemIdentifier {
    static let noteRow = NSUserInterfaceItemIdentifier("noteRow")
}

// MARK: - Coordinator

extension NoteTableView {
    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var notes: [StickyNote] = []
        var selectedIds: Binding<Set<StickyNote.ID>>
        var onDoubleClickNote: (StickyNote) -> Void = { _ in }
        var onDeleteNotes: ([StickyNote]) -> Void = { _ in }
        var onToggleVisibility: (StickyNote) -> Void = { _ in }
        var onTogglePin: (StickyNote) -> Void = { _ in }
        weak var tableView: NSTableView?

        init(
            selectedIds: Binding<Set<StickyNote.ID>>,
            onDoubleClickNote: @escaping (StickyNote) -> Void,
            onDeleteNotes: @escaping ([StickyNote]) -> Void,
            onToggleVisibility: @escaping (StickyNote) -> Void,
            onTogglePin: @escaping (StickyNote) -> Void
        ) {
            self.selectedIds = selectedIds
            self.onDoubleClickNote = onDoubleClickNote
            self.onDeleteNotes = onDeleteNotes
            self.onToggleVisibility = onToggleVisibility
            self.onTogglePin = onTogglePin
        }

        // MARK: - Data Source

        func numberOfRows(in tableView: NSTableView) -> Int { notes.count }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row < notes.count else { return nil }
            let cell = tableView.makeView(withIdentifier: .noteRow, owner: self) as? NoteRowCellView
                ?? NoteRowCellView()
            cell.identifier = .noteRow
            let note = notes[row]
            cell.colorHex = note.colorHex
            cell.title = note.title
            cell.date = note.createdAt
            cell.isPinned = note.isPinned
            cell.isVisible = note.isVisible
            return cell
        }

        // MARK: - Selection

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView else { return }
            let ids = Set(tableView.selectedRowIndexes.compactMap { idx -> UUID? in
                guard notes.indices.contains(idx) else { return nil }
                return notes[idx].id
            })
            selectedIds.wrappedValue = ids
        }

        // MARK: - Context Menu

        func tableView(_ tableView: NSTableView, menuForRow row: Int) -> NSMenu? {
            guard notes.indices.contains(row) else { return nil }
            let note = notes[row]
            let affected = selectedIds.wrappedValue.contains(note.id) ? selectedNotes : [note]

            let menu = NSMenu()

            let hideItem = NSMenuItem(
                title: affected.allSatisfy(\.isVisible) ? tr("Hide") : tr("Show"),
                action: #selector(toggleVisibilityAction(_:)),
                keyEquivalent: ""
            )
            hideItem.representedObject = affected
            menu.addItem(hideItem)

            let pinItem = NSMenuItem(
                title: affected.allSatisfy(\.isPinned) ? tr("Unpin") : tr("Pin"),
                action: #selector(togglePinAction(_:)),
                keyEquivalent: ""
            )
            pinItem.representedObject = affected
            menu.addItem(pinItem)

            menu.addItem(.separator())

            let deleteItem = NSMenuItem(
                title: tr("Delete"),
                action: #selector(deleteAction(_:)),
                keyEquivalent: ""
            )
            deleteItem.representedObject = affected
            deleteItem.isEnabled = true
            menu.addItem(deleteItem)

            return menu
        }

        // MARK: - Double-click

        @objc func doubleClickRow() {
            guard let tableView, let row = tableView.clickedRowIfValid, notes.indices.contains(row) else { return }
            onDoubleClickNote(notes[row])
        }

        // MARK: - Actions

        @objc private func toggleVisibilityAction(_ sender: NSMenuItem) {
            guard let notes = sender.representedObject as? [StickyNote] else { return }
            for note in notes { onToggleVisibility(note) }
        }

        @objc private func togglePinAction(_ sender: NSMenuItem) {
            guard let notes = sender.representedObject as? [StickyNote] else { return }
            for note in notes { onTogglePin(note) }
        }

        @objc private func deleteAction(_ sender: NSMenuItem) {
            guard let notes = sender.representedObject as? [StickyNote] else { return }
            onDeleteNotes(notes)
        }

        // MARK: - Helpers

        private var selectedNotes: [StickyNote] {
            notes.filter { selectedIds.wrappedValue.contains($0.id) }
        }
    }
}

extension NSTableView {
    var clickedRowIfValid: Int? {
        let row = clickedRow
        return row >= 0 ? row : nil
    }
}

// MARK: - Cell View

final class NoteRowCellView: NSTableCellView {
    var colorHex: String = NoteColor.yellow.rawValue {
        didSet { colorDot.layer?.backgroundColor = NSColor(hex: colorHex).cgColor }
    }
    var title: String = "" {
        didSet { titleField.stringValue = title }
    }
    var date: Date = .init() {
        didSet { dateField.objectValue = date }
    }
    var isPinned: Bool = false {
        didSet { pinIcon.isHidden = !isPinned }
    }
    var isVisible: Bool = false {
        didSet { eyeIcon.isHidden = !isVisible }
    }

    private let colorDot: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 6
        v.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            v.widthAnchor.constraint(equalToConstant: 12),
            v.heightAnchor.constraint(equalToConstant: 12),
        ])
        return v
    }()

    private let titleField: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: 13, weight: .medium)
        f.lineBreakMode = .byTruncatingTail
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()

    private let dateField: NSTextField = {
        let f = NSTextField(labelWithString: "")
        f.font = .systemFont(ofSize: 11)
        f.textColor = .secondaryLabelColor
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        f.formatter = df
        f.translatesAutoresizingMaskIntoConstraints = false
        return f
    }()

    private let pinIcon: NSImageView = {
        let i = NSImageView(image: NSImage(systemSymbolName: "pin.fill", accessibilityDescription: nil)!)
        i.contentTintColor = .controlAccentColor
        i.translatesAutoresizingMaskIntoConstraints = false
        return i
    }()

    private let eyeIcon: NSImageView = {
        let i = NSImageView(image: NSImage(systemSymbolName: "eye", accessibilityDescription: nil)!)
        i.contentTintColor = .secondaryLabelColor
        i.translatesAutoresizingMaskIntoConstraints = false
        return i
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) { nil }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 4

        let textStack = NSStackView(views: [titleField, dateField])
        textStack.orientation = .vertical
        textStack.spacing = 1
        textStack.alignment = .leading

        let stack = NSStackView(views: [colorDot, textStack])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.alignment = .centerY
        stack.translatesAutoresizingMaskIntoConstraints = false

        addSubview(stack)
        addSubview(pinIcon)
        addSubview(eyeIcon)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: pinIcon.leadingAnchor, constant: -4),

            pinIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            pinIcon.trailingAnchor.constraint(equalTo: eyeIcon.leadingAnchor, constant: -4),

            eyeIcon.centerYAnchor.constraint(equalTo: centerYAnchor),
            eyeIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),

            titleField.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
            dateField.widthAnchor.constraint(greaterThanOrEqualToConstant: 60),
        ])
    }

    override var backgroundStyle: NSView.BackgroundStyle {
        didSet {
            switch backgroundStyle {
            case .emphasized:
                titleField.textColor = .white
                dateField.textColor = .secondaryLabelColor
                pinIcon.contentTintColor = .white
                eyeIcon.contentTintColor = .white
            default:
                titleField.textColor = .labelColor
                dateField.textColor = .secondaryLabelColor
                pinIcon.contentTintColor = .controlAccentColor
                eyeIcon.contentTintColor = .secondaryLabelColor
            }
        }
    }
}
