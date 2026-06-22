//
//  SettingsView.swift
//  mdsticky
//
//  Application settings with multi-service sync management.
//

import SwiftUI
import ServiceManagement
import AppKit
import UniformTypeIdentifiers

enum SettingsTab: CaseIterable {
    case general
    case sync
    case languageAppearance

    var key: String {
        switch self {
        case .general: return "General"
        case .sync: return "Sync"
        case .languageAppearance: return "Language & Appearance"
        }
    }

    var icon: String {
        switch self {
        case .general: return "gear"
        case .sync: return "arrow.triangle.2.circlepath"
        case .languageAppearance: return "globe"
        }
    }
}

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var provider = SyncServiceProvider.shared
    @State private var selectedTab: SettingsTab = .general
    @State private var testStatus: [String: String] = [:]
    @State private var isTesting: Set<String> = []
    @State private var deleteTarget: SyncServiceConfig? = nil
    @State private var primaryTarget: SyncServiceConfig? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 2) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))
                            Text(verbatim: tr(tab.key))
                                .font(.caption2)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                        .background(selectedTab == tab ? Color.accentColor.opacity(0.12) : Color.clear)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedTab == tab ? Color.accentColor : Color.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 2)
            .padding(.bottom, 4)

            Divider()

            switch selectedTab {
            case .general:
                generalTab
            case .sync:
                syncTab
            case .languageAppearance:
                languageAppearanceTab
            }
        }
        .frame(minWidth: 540, minHeight: 460)
        .id("settings-\(settings.language)")
        .environment(\.locale, Locale(identifier: settings.language))
        .preferredColorScheme(settings.colorSchemeMode.resolved)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section(tr("Startup")) {
                Toggle(tr("Launch at login and restore desktop notes"), isOn: $settings.autoStart)
                    .onChange(of: settings.autoStart) { _, enabled in
                        AutoStartService.shared.setEnabled(enabled)
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Language & Appearance

    private var languageAppearanceTab: some View {
        Form {
            Section {
                Picker(selection: $settings.language) {
                    Text("简体中文").tag("zh-Hans")
                    Text("English").tag("en")
                    Text("繁體中文").tag("zh-Hant")
                    Text("日本語").tag("ja")
                    Text("한국어").tag("ko")
                    Text("Français").tag("fr")
                    Text("Deutsch").tag("de")
                    Text("Español").tag("es")
                    Text("Português (Brasil)").tag("pt-BR")
                    Text("Русский").tag("ru")
                } label: {
                    Text(verbatim: tr("Language"))
                }
                .pickerStyle(.menu)
            } header: {
                Text(verbatim: tr("Language"))
            }

            Section {
                Picker(selection: $settings.colorSchemeMode) {
                    Text("System").tag(ColorSchemeMode.system)
                    Text("Light").tag(ColorSchemeMode.light)
                    Text("Dark").tag(ColorSchemeMode.dark)
                } label: {
                    Text(verbatim: tr("Appearance"))
                }
                .pickerStyle(.segmented)
            } header: {
                Text(verbatim: tr("Appearance"))
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Sync

    private var syncTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(verbatim: tr("Sync Services"))
                    .font(.headline)
                Spacer()
                Menu {
                    ForEach(SyncServiceType.allCases) { type in
                        Button(type.displayName) { provider.addService(type: type) }
                    }
                } label: {
                    Text(verbatim: tr("Add Service"))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 80)

                Button(tr("Sync All")) {
                    Task { await provider.syncAll() }
                }
                .disabled(provider.enabledConfigs.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            if provider.configs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.title).foregroundStyle(.secondary)
                    Text(verbatim: tr("No sync services yet. Click \"Add Service\" to start.")).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(provider.configs) { config in
                            serviceCard(for: config)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
        .confirmationDialog(tr("Confirm Delete"), isPresented: .init(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button(tr("Delete"), role: .destructive) {
                if let target = deleteTarget { provider.removeService(target) }
                deleteTarget = nil
            }
            Button(tr("Cancel"), role: .cancel) { deleteTarget = nil }
        } message: {
            Text(verbatim: {
                let fmt = tr("Are you sure you want to delete the sync service \"%@\"? This action cannot be undone.")
                return String(format: fmt, deleteTarget?.displayName ?? "")
            }())
        }
        .confirmationDialog(tr("Set as Primary"), isPresented: .init(
            get: { primaryTarget != nil },
            set: { if !$0 { primaryTarget = nil } }
        )) {
            Button(tr("Set as Primary")) {
                if let target = primaryTarget { provider.setPrimary(target) }
                primaryTarget = nil
            }
            Button(tr("Cancel"), role: .cancel) { primaryTarget = nil }
        } message: {
            Text(verbatim: {
                let fmt = tr("Set \"%@\" as the primary sync service? It will sync bidirectionally in real time.")
                return String(format: fmt, primaryTarget?.displayName ?? "")
            }())
        }
    }

    // MARK: - Service Card

    @ViewBuilder
    private func serviceCard(for config: SyncServiceConfig) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header row
            HStack(spacing: 8) {
                Image(systemName: serviceIcon(for: config.type))
                    .font(.title3)
                    .foregroundStyle(config.isEnabled ? Color.accentColor : .secondary)

                TextField(tr("Service Name"), text: .init(
                    get: { config.name },
                    set: { var c = config; c.name = $0; provider.updateConfig(c) }
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 14, weight: .medium))

                Spacer()

                Toggle("", isOn: .init(
                    get: { config.isEnabled },
                    set: { var c = config; c.isEnabled = $0; provider.updateConfig(c) }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .tint(config.isPrimary ? Color.accentColor : nil)
            }

            Divider()

            // Config fields
            configFields(for: config)

            Divider()

            // Footer
            HStack {
                Picker(selection: .init(
                    get: { config.frequency },
                    set: { var c = config; c.frequency = $0; provider.updateConfig(c) }
                )) {
                    ForEach(SyncFrequency.allCases) { f in Text(f.displayName).tag(f) }
                } label: {
                    Text(verbatim: tr("Sync Frequency"))
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 200)

                Spacer()

                HStack(spacing: 4) {
                    Text(verbatim: config.isPrimary ? tr("Primary Service") : tr("Not Primary"))
                        .font(.caption)
                        .foregroundStyle(config.isPrimary ? .green : .secondary)

                    if config.isEnabled && !config.isPrimary {
                        Button(tr("Set as Primary")) {
                            primaryTarget = config
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    if let date = config.lastSyncDate {
                        (Text(verbatim: tr("Last: ")) + Text(date, format: .dateTime.hour().minute()))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    testButton(for: config)

                    Button {
                        deleteTarget = config
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.red)
                }
            }

            if let err = config.lastError {
                Text(err).font(.caption2).foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(config.isPrimary ? Color.accentColor.opacity(0.3) : Color.primary.opacity(0.08), lineWidth: 1)
        )
    }

    private func serviceIcon(for type: SyncServiceType) -> String {
        switch type {
        case .webdav: return "icloud"
        case .localFolder: return "folder"
        case .samba: return "externaldrive.connected.to.line.below"
        }
    }

    // MARK: - Config Fields

    @ViewBuilder
    private func configFields(for config: SyncServiceConfig) -> some View {
        Group {
            switch config.type {
            case .webdav:
                webdavFields(for: config)
            case .localFolder:
                localFolderFields(for: config)
            case .samba:
                sambaFields(for: config)
            }
        }
    }

    private func webdavFields(for config: SyncServiceConfig) -> some View {
        VStack(spacing: 6) {
            labeledField(tr("Server"), binding(for: config, keyPath: \.webdavURL), placeholder: "https://dav.example.com/remote.php/dav/files/user/")
            HStack(spacing: 8) {
                labeledField(tr("Username"), binding(for: config, keyPath: \.webdavUsername), placeholder: "")
                    .frame(maxWidth: .infinity)
                labeledField(tr("Password"), binding(for: config, keyPath: \.webdavPassword), placeholder: "", secure: true)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func localFolderFields(for config: SyncServiceConfig) -> some View {
        HStack(spacing: 8) {
            labeledField(tr("Path"), binding(for: config, keyPath: \.localFolderPath), placeholder: "~/Documents/mdsticky_backup")

            Button(tr("Choose Folder…")) {
                selectFolder(for: config)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .font(.caption)
        }
    }

    private func sambaFields(for config: SyncServiceConfig) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                labeledField(tr("Path"), binding(for: config, keyPath: \.sambaPath), placeholder: "/Volumes/ShareName/folder")
                Button(tr("Browse…")) { selectFolder(for: config) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .font(.caption)
            }
        }
    }

    private func labeledField(_ label: String, _ binding: Binding<String>, placeholder: String, secure: Bool = false) -> some View {
        HStack(spacing: 0) {
            Text("\(label):").font(.caption).foregroundStyle(.secondary).frame(width: 42, alignment: .trailing)
            if secure {
                SecureField(placeholder, text: binding)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            } else {
                TextField(placeholder, text: binding)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
            }
        }
    }

    // MARK: - Bindings

    private func binding(for config: SyncServiceConfig, keyPath: WritableKeyPath<SyncServiceConfig, String>) -> Binding<String> {
        Binding<String>(
            get: { provider.configs.first(where: { $0.id == config.id })?[keyPath: keyPath] ?? "" },
            set: { newValue in
                if var c = provider.configs.first(where: { $0.id == config.id }) {
                    c[keyPath: keyPath] = newValue
                    provider.updateConfig(c)
                }
            }
        )
    }

    // MARK: - Folder Picker

    private func selectFolder(for config: SyncServiceConfig) {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"
        panel.message = "Choose sync target folder"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            let bookmark = try? url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )

            let path = url.path

            if var c = provider.configs.first(where: { $0.id == config.id }) {
                switch c.type {
                case .localFolder:
                    c.localFolderPath = path
                case .samba:
                    c.sambaPath = path
                default:
                    break
                }
                c.folderBookmark = bookmark
                provider.updateConfig(c)
            }
        }
    }

    // MARK: - Test

    private func testButton(for config: SyncServiceConfig) -> some View {
        Button {
            testConnection(config)
        } label: {
            if isTesting.contains(config.id) {
                ProgressView().controlSize(.small).frame(width: 14, height: 14)
            } else {
                Text(verbatim: tr("Test")).font(.caption)
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .disabled(isTesting.contains(config.id))
    }

    private func testConnection(_ config: SyncServiceConfig) {
        isTesting.insert(config.id)
            testStatus[config.id] = tr("Testing…")
        let cfg = config
        Task {
            let svc = provider.service(for: cfg) ?? {
                switch cfg.type {
                case .webdav: return WebDAVSyncService(config: cfg)
                case .localFolder: return LocalFolderSyncService(config: cfg)
                case .samba: return SambaSyncService(config: cfg)
                }
            }()
            let ok = await svc.testConnection()
            testStatus[config.id] = ok ? tr("Connection Successful") : tr("Connection Failed")
            isTesting.remove(config.id)
        }
    }
}

#Preview {
    SettingsView()
}
