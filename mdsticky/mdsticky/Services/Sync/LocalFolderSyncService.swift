//
//  LocalFolderSyncService.swift
//  mdsticky
//
//  Sync to a local folder (simple file copy).
//  Supports security-scoped bookmarks for sandboxed folder access.
//

import Foundation

final class LocalFolderSyncService: SyncServiceProtocol {
    let config: SyncServiceConfig
    private(set) var isSyncing: Bool = false
    private(set) var lastSyncDate: Date?
    private(set) var lastError: String?

    private let resolvedURL: URL?

    private var targetDir: URL? {
        resolvedURL?.appendingPathComponent("mdsticky_notes", isDirectory: true)
    }

    private var sourceDir: URL {
        NoteStorageService.shared.allNoteURLs().first?.deletingLastPathComponent()
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("mdsticky/notes", isDirectory: true)
    }

    init(config: SyncServiceConfig) {
        self.config = config
        self.resolvedURL = Self.resolveBookmark(config)
    }

    private static func resolveBookmark(_ config: SyncServiceConfig) -> URL? {
        if let bookmark = config.folderBookmark {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope,
                                  relativeTo: nil, bookmarkDataIsStale: &isStale) {
                return url
            }
        }
        let path = config.localFolderPath
        guard !path.isEmpty else { return nil }
        return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
    }

    private func withSecurityAccess<T>(_ block: () throws -> T) rethrows -> T {
        _ = resolvedURL?.startAccessingSecurityScopedResource()
        defer { resolvedURL?.stopAccessingSecurityScopedResource() }
        return try block()
    }

    func testConnection() async -> Bool {
        guard let dir = targetDir else { return false }
        return withSecurityAccess {
            let created = (try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)) != nil
            return created && FileManager.default.isWritableFile(atPath: dir.path)
        }
    }

    func upload(fileName: String) async throws {
        guard let dir = targetDir else { throw SyncError.notConfigured }
        try withSecurityAccess {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let localURL = sourceDir.appendingPathComponent(fileName)
            let destURL = dir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: destURL.path) {
                try FileManager.default.removeItem(at: destURL)
            }
            try FileManager.default.copyItem(at: localURL, to: destURL)
        }
    }

    func download(fileName: String) async throws -> Data {
        guard let dir = targetDir else { throw SyncError.notConfigured }
        return try withSecurityAccess {
            let src = dir.appendingPathComponent(fileName)
            guard FileManager.default.fileExists(atPath: src.path) else { throw SyncError.downloadFailed }
            return try Data(contentsOf: src)
        }
    }

    func deleteRemote(fileName: String) async throws {
        guard let dir = targetDir else { return }
        try withSecurityAccess {
            let url = dir.appendingPathComponent(fileName)
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
        }
    }

    func listRemoteFiles() async throws -> [String: Date] {
        guard let dir = targetDir else { return [:] }
        return try withSecurityAccess {
            guard FileManager.default.fileExists(atPath: dir.path) else { return [:] }
            let urls = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
            var result: [String: Date] = [:]
            for url in urls where url.pathExtension.lowercased() == "md" {
                result[url.lastPathComponent] = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            }
            return result
        }
    }

    func syncNotes(fileNames: [String], direction: SyncDirection) async {
        guard !isSyncing else { return }
        isSyncing = true
        lastError = nil

        do {
            guard let dir = targetDir else { throw SyncError.notConfigured }
            try withSecurityAccess {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

                if direction == .bidirectional {
                    let remoteFiles = (try? listRemoteFilesSync(dir: dir)) ?? [:]
                    for (name, remoteMod) in remoteFiles {
                        let localURL = sourceDir.appendingPathComponent(name)
                        let localMod = (try? localURL.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
                        if localMod == nil || remoteMod > localMod! {
                            let data = try Data(contentsOf: dir.appendingPathComponent(name))
                            try data.write(to: localURL, options: .atomic)
                        }
                    }
                }

                for name in fileNames {
                    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let localURL = sourceDir.appendingPathComponent(name)
                    let destURL = dir.appendingPathComponent(name)
                    if FileManager.default.fileExists(atPath: destURL.path) {
                        try FileManager.default.removeItem(at: destURL)
                    }
                    try FileManager.default.copyItem(at: localURL, to: destURL)
                }
            }

            lastSyncDate = Date()
        } catch {
            lastError = error.localizedDescription
        }

        isSyncing = false
    }

    private func listRemoteFilesSync(dir: URL) throws -> [String: Date] {
        guard FileManager.default.fileExists(atPath: dir.path) else { return [:] }
        let urls = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])
        var result: [String: Date] = [:]
        for url in urls where url.pathExtension.lowercased() == "md" {
            result[url.lastPathComponent] = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        }
        return result
    }
}
