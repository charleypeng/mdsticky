//
//  SyncServiceProvider.swift
//  mdsticky
//
//  Manages all sync service instances, scheduling, and execution.
//

import Foundation
import Combine
import SwiftData

enum SyncError: LocalizedError {
    case notConfigured
    case connectionFailed
    case uploadFailed
    case downloadFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .notConfigured: return tr("Service not configured")
        case .connectionFailed: return tr("Connection Failed")
        case .uploadFailed: return tr("Upload failed")
        case .downloadFailed: return tr("Download failed")
        case .deleteFailed: return tr("Delete failed")
        }
    }
}

@MainActor
final class SyncServiceProvider: ObservableObject {
    static let shared = SyncServiceProvider()

    @Published var configs: [SyncServiceConfig] = [] {
        didSet { persistConfigs() }
    }

    @Published var isSyncing: Bool = false
    @Published var lastError: String?

    private var services: [String: SyncServiceProtocol] = [:]
    private var fileMonitorSource: DispatchSourceFileSystemObject?
    private var monitorDescriptor: Int32 = -1
    private var dailyTimer: Timer?
    private var syncDebounceTask: Task<Void, Never>?
    private var notesDir: URL

    private struct Keys {
        static let configs = "mdsticky.syncServices"
    }

    private init() {
        notesDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("mdsticky/notes", isDirectory: true)
        loadConfigs()
        rebuildServices()
        scheduleDailyTimer()
    }

    // MARK: - Config Management

    var primaryConfig: SyncServiceConfig? {
        configs.first { $0.isPrimary && $0.isEnabled }
    }

    var enabledConfigs: [SyncServiceConfig] {
        configs.filter { $0.isEnabled }
    }

    func addService(type: SyncServiceType) {
        var config = SyncServiceConfig(type: type)
        config.name = type.displayName
        switch type {
        case .webdav:
            config.frequency = configs.isEmpty ? .realtime : .daily
        case .localFolder, .samba:
            config.frequency = .daily
        }
        if configs.isEmpty { config.isPrimary = true }
        configs.append(config)
    }

    func removeService(_ config: SyncServiceConfig) {
        configs.removeAll { $0.id == config.id }
        services.removeValue(forKey: config.id)
    }

    func updateConfig(_ config: SyncServiceConfig) {
        guard let idx = configs.firstIndex(where: { $0.id == config.id }) else { return }
        configs[idx] = config
        services[config.id] = makeService(for: config)
    }

    func setPrimary(_ config: SyncServiceConfig) {
        for i in configs.indices { configs[i].isPrimary = (configs[i].id == config.id) }
        if let primaryConfig {
            var c = primaryConfig
            c.frequency = .realtime
            updateConfig(c)
        }
        Task { await syncAll() }
    }

    // MARK: - Services

    func service(for config: SyncServiceConfig) -> SyncServiceProtocol? {
        services[config.id]
    }

    private func rebuildServices() {
        services.removeAll()
        for config in configs where config.isEnabled {
            services[config.id] = makeService(for: config)
        }
    }

    private func makeService(for config: SyncServiceConfig) -> SyncServiceProtocol {
        switch config.type {
        case .webdav:    return WebDAVSyncService(config: config)
        case .localFolder: return LocalFolderSyncService(config: config)
        case .samba:     return SambaSyncService(config: config)
        }
    }

    // MARK: - Sync

    func syncAll() async {
        guard !isSyncing else { return }
        isSyncing = true
        lastError = nil

        let context = mdstickyApp.sharedContainer.mainContext
        let desc = FetchDescriptor<StickyNote>()
        let fileNames = (try? context.fetch(desc))?.map(\.contentFileName) ?? []

        for config in enabledConfigs {
            guard let svc = services[config.id] else { continue }
            let direction: SyncDirection = config.isPrimary ? .bidirectional : .uploadOnly
            await svc.syncNotes(fileNames: fileNames, direction: direction)

            if let idx = configs.firstIndex(where: { $0.id == config.id }) {
                configs[idx].lastSyncDate = svc.lastSyncDate
                configs[idx].lastError = svc.lastError
            }
        }

        isSyncing = false
    }

    func upload(note: StickyNote) async {
        for config in enabledConfigs {
            guard let svc = services[config.id] else { continue }
            try? await svc.upload(fileName: note.contentFileName)
        }
    }

    func deleteRemote(for note: StickyNote) async {
        for config in enabledConfigs {
            guard let svc = services[config.id] else { continue }
            try? await svc.deleteRemote(fileName: note.contentFileName)
        }
    }

    // MARK: - Monitoring

    func startMonitoring() {
        stopMonitoring()
        try? FileManager.default.createDirectory(at: notesDir, withIntermediateDirectories: true)
        monitorDescriptor = open(notesDir.path, O_EVTONLY)
        guard monitorDescriptor >= 0 else { return }

        fileMonitorSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: monitorDescriptor,
            eventMask: [.write, .rename, .delete],
            queue: .main
        )
        fileMonitorSource?.setEventHandler { [weak self] in
            self?.onDirectoryChanged()
        }
        fileMonitorSource?.setCancelHandler { [weak self] in
            if let fd = self?.monitorDescriptor, fd >= 0 { close(fd); self?.monitorDescriptor = -1 }
        }
        fileMonitorSource?.resume()
    }

    func stopMonitoring() {
        fileMonitorSource?.cancel()
        fileMonitorSource = nil
    }

    private func onDirectoryChanged() {
        syncDebounceTask?.cancel()
        syncDebounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            await self?.syncAll()
        }
    }

    // MARK: - Scheduling

    private func scheduleDailyTimer() {
        dailyTimer?.invalidate()
        dailyTimer = Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.runDailySyncs() }
        }
    }

    private func runDailySyncs() async {
        let context = mdstickyApp.sharedContainer.mainContext
        let fileNames = (try? context.fetch(FetchDescriptor<StickyNote>()))?.map(\.contentFileName) ?? []

        for config in enabledConfigs where config.frequency == .daily {
            guard let svc = services[config.id] else { continue }
            let direction: SyncDirection = config.isPrimary ? .bidirectional : .uploadOnly
            await svc.syncNotes(fileNames: fileNames, direction: direction)
        }
    }

    // MARK: - Persistence

    private func persistConfigs() {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        UserDefaults.standard.set(data, forKey: Keys.configs)
    }

    private func loadConfigs() {
        guard let data = UserDefaults.standard.data(forKey: Keys.configs),
              let loaded = try? JSONDecoder().decode([SyncServiceConfig].self, from: data) else {
            configs = []
            return
        }
        configs = loaded
    }
}
