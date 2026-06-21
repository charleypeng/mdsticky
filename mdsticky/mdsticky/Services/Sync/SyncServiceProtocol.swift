//
//  SyncServiceProtocol.swift
//  mdsticky
//
//  Protocol for sync service backends (WebDAV, local folder, Samba, etc.).
//

import Foundation

enum SyncDirection {
    case bidirectional
    case uploadOnly
}

enum SyncFrequency: String, Codable, CaseIterable, Identifiable {
    case realtime = "realtime"
    case daily = "daily"
    case manual = "manual"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .realtime: return "实时"
        case .daily: return "每天一次"
        case .manual: return "手动"
        }
    }
}

enum SyncServiceType: String, Codable, CaseIterable, Identifiable {
    case webdav = "webdav"
    case localFolder = "localFolder"
    case samba = "samba"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .webdav: return "WebDAV"
        case .localFolder: return "本地文件夹"
        case .samba: return "Samba"
        }
    }
}

struct SyncServiceConfig: Codable, Identifiable, Equatable {
    var id: String = UUID().uuidString
    var type: SyncServiceType = .webdav
    var name: String = ""
    var isEnabled: Bool = false
    var frequency: SyncFrequency = .daily
    var isPrimary: Bool = false

    // WebDAV
    var webdavURL: String = ""
    var webdavUsername: String = ""
    var webdavPassword: String = ""

    // Local folder / Samba
    var localFolderPath: String = ""
    var sambaPath: String = ""
    var sambaUsername: String = ""
    var sambaPassword: String = ""

    // Security-scoped bookmark for sandboxed folder access
    var folderBookmark: Data? = nil

    var lastSyncDate: Date?
    var lastError: String?

    var displayName: String {
        !name.isEmpty ? name : type.displayName
    }

    static func == (lhs: SyncServiceConfig, rhs: SyncServiceConfig) -> Bool {
        lhs.id == rhs.id
    }
}

protocol SyncServiceProtocol: AnyObject {
    var config: SyncServiceConfig { get }
    var isSyncing: Bool { get }
    var lastSyncDate: Date? { get }
    var lastError: String? { get }

    func testConnection() async -> Bool
    func upload(fileName: String) async throws
    func download(fileName: String) async throws -> Data
    func deleteRemote(fileName: String) async throws
    func listRemoteFiles() async throws -> [String: Date]
    func syncNotes(fileNames: [String], direction: SyncDirection) async
}
