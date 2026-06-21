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

struct SettingsView: View {
    @StateObject private var settings = AppSettings.shared
    @StateObject private var provider = SyncServiceProvider.shared
    @State private var testStatus: [String: String] = [:]
    @State private var isTesting: Set<String> = []
    @State private var deleteTarget: SyncServiceConfig? = nil

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("通用", systemImage: "gear") }
            syncTab
                .tabItem { Label("同步", systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(minWidth: 540, minHeight: 460)
        .padding(.vertical, 8)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("启动") {
                Toggle("随系统启动并恢复桌面便利贴", isOn: $settings.autoStart)
                    .onChange(of: settings.autoStart) { _, enabled in
                        AutoStartService.shared.setEnabled(enabled)
                    }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    // MARK: - Sync

    private var syncTab: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("同步服务")
                    .font(.headline)
                Spacer()
                Menu("添加服务") {
                    ForEach(SyncServiceType.allCases) { type in
                        Button(type.displayName) { provider.addService(type: type) }
                    }
                }
                .menuStyle(.borderlessButton)
                .frame(width: 80)

                Button("全部同步") {
                    Task { await provider.syncAll() }
                }
                .disabled(provider.enabledConfigs.isEmpty)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            if provider.configs.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "tray").font(.title).foregroundStyle(.secondary)
                    Text("暂无同步服务，点击「添加服务」开始").foregroundStyle(.secondary)
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
        .confirmationDialog("确认删除", isPresented: .init(
            get: { deleteTarget != nil },
            set: { if !$0 { deleteTarget = nil } }
        )) {
            Button("删除", role: .destructive) {
                if let target = deleteTarget { provider.removeService(target) }
                deleteTarget = nil
            }
            Button("取消", role: .cancel) { deleteTarget = nil }
        } message: {
            Text("确定要删除同步服务「\(deleteTarget?.displayName ?? "")」吗？此操作不可撤销。")
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

                TextField("服务名称", text: .init(
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
            }

            Divider()

            // Config fields
            configFields(for: config)

            Divider()

            // Footer
            HStack {
                Picker("同步频率", selection: .init(
                    get: { config.frequency },
                    set: { var c = config; c.frequency = $0; provider.updateConfig(c) }
                )) {
                    ForEach(SyncFrequency.allCases) { f in Text(f.displayName).tag(f) }
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                .frame(width: 200)

                Spacer()

                HStack(spacing: 4) {
                    Text(config.isPrimary ? "已设为主服务" : "非主服务")
                        .font(.caption)
                        .foregroundStyle(config.isPrimary ? .green : .secondary)

                    if config.isEnabled {
                        Button(config.isPrimary ? "" : "设为主") {
                            provider.setPrimary(config)
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .controlSize(.small)
                    }
                }

                Spacer()

                HStack(spacing: 6) {
                    if let date = config.lastSyncDate {
                        Text("上次: \(date, format: .dateTime.hour().minute())")
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
            labeledField("服务器", binding(for: config, keyPath: \.webdavURL), placeholder: "https://dav.example.com/remote.php/dav/files/user/")
            HStack(spacing: 8) {
                labeledField("用户名", binding(for: config, keyPath: \.webdavUsername), placeholder: "")
                    .frame(maxWidth: .infinity)
                labeledField("密码", binding(for: config, keyPath: \.webdavPassword), placeholder: "", secure: true)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func localFolderFields(for config: SyncServiceConfig) -> some View {
        HStack(spacing: 8) {
            labeledField("路径", binding(for: config, keyPath: \.localFolderPath), placeholder: "~/Documents/mdsticky_backup")

            Button("选择文件夹...") {
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
                labeledField("路径", binding(for: config, keyPath: \.sambaPath), placeholder: "/Volumes/ShareName/folder")
                Button("选择...") { selectFolder(for: config) }
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
        panel.prompt = "选择文件夹"
        panel.message = "选择同步目标文件夹"

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
                Text("测试").font(.caption)
            }
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .disabled(isTesting.contains(config.id))
    }

    private func testConnection(_ config: SyncServiceConfig) {
        isTesting.insert(config.id)
        testStatus[config.id] = "测试中..."
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
            testStatus[config.id] = ok ? "连接成功" : "连接失败"
            isTesting.remove(config.id)
        }
    }
}

#Preview {
    SettingsView()
}
