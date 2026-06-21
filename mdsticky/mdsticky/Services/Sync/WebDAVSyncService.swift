//
//  WebDAVSyncService.swift
//  mdsticky
//
//  WebDAV sync backend.
//

import Foundation

final class WebDAVSyncService: SyncServiceProtocol {
    let config: SyncServiceConfig
    private(set) var isSyncing: Bool = false
    private(set) var lastSyncDate: Date?
    private(set) var lastError: String?

    private let session: URLSession

    private var baseURL: URL? {
        let raw = config.webdavURL
        guard !raw.isEmpty else { return nil }
        let url = raw.hasSuffix("/") ? raw : raw + "/"
        return URL(string: url)?.appendingPathComponent("notes", isDirectory: true)
    }

    private var authHeader: String? {
        let loginString = "\(config.webdavUsername):\(config.webdavPassword)"
        guard let loginData = loginString.data(using: .utf8) else { return nil }
        return "Basic \(loginData.base64EncodedString())"
    }

    init(config: SyncServiceConfig) {
        self.config = config
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 30
        cfg.timeoutIntervalForResource = 120
        session = URLSession(configuration: cfg)
    }

    func testConnection() async -> Bool {
        guard let url = baseURL, let auth = authHeader else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "PROPFIND"
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.setValue("0", forHTTPHeaderField: "Depth")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.httpBody = propfindXML(depth: "0")
        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 207
        } catch {
            return false
        }
    }

    func upload(fileName: String) async throws {
        guard let base = baseURL, let auth = authHeader else { return }
        let localURL = notesDir.appendingPathComponent(fileName)
        let data = try Data(contentsOf: localURL)
        let remoteURL = base.appendingPathComponent(fileName)

        var request = URLRequest(url: remoteURL)
        request.httpMethod = "PUT"
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.httpBody = data

        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw SyncError.uploadFailed
        }
    }

    func download(fileName: String) async throws -> Data {
        guard let base = baseURL, let auth = authHeader else { throw SyncError.notConfigured }
        let remoteURL = base.appendingPathComponent(fileName)
        var request = URLRequest(url: remoteURL)
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw SyncError.downloadFailed }
        return data
    }

    func deleteRemote(fileName: String) async throws {
        guard let base = baseURL, let auth = authHeader else { return }
        let remoteURL = base.appendingPathComponent(fileName)
        var request = URLRequest(url: remoteURL)
        request.httpMethod = "DELETE"
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        let (_, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) || http.statusCode == 404 else {
            throw SyncError.deleteFailed
        }
    }

    func listRemoteFiles() async throws -> [String: Date] {
        guard let base = baseURL, let auth = authHeader else { return [:] }
        var request = URLRequest(url: base)
        request.httpMethod = "PROPFIND"
        request.setValue(auth, forHTTPHeaderField: "Authorization")
        request.setValue("1", forHTTPHeaderField: "Depth")
        request.setValue("application/xml", forHTTPHeaderField: "Content-Type")
        request.httpBody = propfindXML(depth: "1")

        let (data, response) = try await session.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 207 else {
            throw SyncError.connectionFailed
        }
        return parsePropfind(data: data, baseURL: base)
    }

    func syncNotes(fileNames: [String], direction: SyncDirection) async {
        guard !isSyncing else { return }
        isSyncing = true
        lastError = nil

        do {
            let remoteFiles = try await listRemoteFiles()

            if direction == .bidirectional {
                for (name, remoteMod) in remoteFiles {
                    let localURL = NoteStorageService.shared.allNoteURLs().first { $0.lastPathComponent == name }
                    let localMod = localURL.flatMap { modificationDate(of: $0) }
                    if localMod == nil || remoteMod > localMod! {
                        let data = try await download(fileName: name)
                        let target = (localURL ?? notesDir.appendingPathComponent(name))
                        try data.write(to: target, options: .atomic)
                    }
                }
            }

            for name in fileNames {
                try await upload(fileName: name)
            }

            lastSyncDate = Date()
        } catch {
            lastError = error.localizedDescription
        }

        isSyncing = false
    }

    // MARK: - Helpers

    private var notesDir: URL {
        NoteStorageService.shared.allNoteURLs().first?.deletingLastPathComponent()
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("mdsticky/notes", isDirectory: true)
    }

    private func propfindXML(depth: String) -> Data {
        """
        <?xml version="1.0" encoding="utf-8"?>
        <D:propfind xmlns:D="DAV:"><D:prop><D:getlastmodified/><D:getcontentlength/></D:prop></D:propfind>
        """.data(using: .utf8)!
    }

    private func parsePropfind(data: Data, baseURL: URL) -> [String: Date] {
        var result: [String: Date] = [:]
        guard let xml = try? XMLDocument(data: data, options: [.documentTidyXML]) else { return result }
        guard let responses = xml.rootElement()?.elements(forName: "response"), !responses.isEmpty else { return result }

        for elem in responses {
            guard let href = elem.elements(forName: "href").first?.stringValue?.removingPercentEncoding else { continue }
            guard let basePath = baseURL.path.removingPercentEncoding else { continue }
            if let p = URL(string: href)?.path.removingPercentEncoding, p == basePath { continue }
            let name = (href as NSString).lastPathComponent
            guard !name.isEmpty, name.lowercased().hasSuffix(".md") else { continue }

            for prop in elem.elements(forName: "prop") {
                if let raw = prop.elements(forName: "getlastmodified").first?.stringValue,
                   let date = parseRFC1123(raw) {
                    result[name] = date
                }
            }
        }
        return result
    }

    private func parseRFC1123(_ s: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss z"
        return f.date(from: s)
    }

    private func modificationDate(of url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }
}
