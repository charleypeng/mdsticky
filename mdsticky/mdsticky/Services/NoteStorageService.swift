//
//  NoteStorageService.swift
//  mdsticky
//
//  File-system storage for sticky note markdown content.
//

import Foundation

final class NoteStorageService {
    static let shared = NoteStorageService()

    private let fileManager = FileManager.default

    private var appSupportDirectory: URL {
        let url = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("mdsticky", isDirectory: true)
        return url
    }

    private var notesDirectory: URL {
        appSupportDirectory.appendingPathComponent("notes", isDirectory: true)
    }

    private init() {}

    func ensureDirectoriesExist() throws {
        try fileManager.createDirectory(at: notesDirectory, withIntermediateDirectories: true)
    }

    func fileURL(for note: StickyNote) -> URL {
        notesDirectory.appendingPathComponent(note.contentFileName)
    }

    static func generateFileName(date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH.mm"
        formatter.locale = Locale(identifier: "zh_CN")
        return "\(formatter.string(from: date)).md"
    }

    static func uniqueFileName(date: Date = Date()) -> String {
        let base = generateFileName(date: date).replacingOccurrences(of: ".md", with: "")
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("mdsticky/notes", isDirectory: true)
        var name = "\(base).md"
        var counter = 1
        while FileManager.default.fileExists(atPath: dir.appendingPathComponent(name).path) {
            name = "\(base)-\(counter).md"
            counter += 1
        }
        return name
    }

    func save(content: String, for note: StickyNote) throws {
        try ensureDirectoriesExist()
        let url = fileURL(for: note)
        try content.write(to: url, atomically: true, encoding: .utf8)
        note.touch()
    }

    func load(for note: StickyNote) throws -> String {
        let url = fileURL(for: note)
        guard fileManager.fileExists(atPath: url.path) else { return "" }
        return try String(contentsOf: url, encoding: .utf8)
    }

    func delete(for note: StickyNote) throws {
        let url = fileURL(for: note)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    func allNoteURLs() -> [URL] {
        guard let urls = try? fileManager.contentsOfDirectory(at: notesDirectory, includingPropertiesForKeys: nil)
        else { return [] }
        return urls.filter { $0.pathExtension.lowercased() == "md" }
    }
}
