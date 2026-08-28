import AppKit
import ApplicationServices
import Combine
import ServiceManagement
import SwiftUI
import XboxMicroCore

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard = "状态总览"
    case mapping = "按键映射"
    case workflows = "提示词预设"
    case diagnostics = "诊断与权限"
    case settings = "设置与数据"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .dashboard: "gauge.with.dots.needle.50percent"
        case .mapping: "gamecontroller"
        case .workflows: "text.bubble"
        case .diagnostics: "stethoscope"
        case .settings: "gearshape"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var selection: SidebarItem? = .dashboard
    @Published var config: OpenMicroConfig
    @Published private(set) var savedConfig: OpenMicroConfig
    @Published var selectedLayer = 0
    @Published var userMessage: String?
    @Published var errorMessage: String?
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var codexInstalled = false
    @Published private(set) var hooksInstalled = false
    @Published private(set) var loginItemEnabled = false
    @Published var autoStartEngine: Bool {
        didSet { UserDefaults.standard.set(autoStartEngine, forKey: Self.autoStartKey) }
    }

    let engine = EngineManager()
    let store: ConfigStore
    private var engineObservation: AnyCancellable?
    private var didStart = false
    private static let autoStartKey = "autoStartEngine"

    init(store: ConfigStore = ConfigStore()) {
        self.store = store
        let loaded: OpenMicroConfig
        let initialLoadError: String?
        do {
            loaded = try store.load()
            initialLoadError = nil
        } catch {
            loaded = .chineseDefault
            initialLoadError = "现有配置无法读取，文件未被覆盖：\(error.localizedDescription)"
        }
        config = loaded
        savedConfig = loaded
        errorMessage = initialLoadError
        autoStartEngine = UserDefaults.standard.object(forKey: Self.autoStartKey) as? Bool ?? true
        engineObservation = engine.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in self?.objectWillChange.send() }
        }
        refreshDiagnostics()
    }

    var hasUnsavedChanges: Bool { config != savedConfig }
    var configPath: String { store.url.path }

    func startIfNeeded() {
        guard !didStart else { return }
        didStart = true
        if autoStartEngine { engine.start() }
    }

    func saveAndApply() {
        do {
            try store.save(config)
            savedConfig = config
            errorMessage = nil
            userMessage = "配置已保存并应用"
            if engine.isRunning { engine.restart() }
            refreshDiagnostics()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func discardChanges() {
        config = savedConfig
        userMessage = "已恢复为上次保存的配置"
    }

    func applyPreset(_ preset: InteractionPreset) {
        config = preset.config
        selectedLayer = 0
        userMessage = "已载入“\(preset.name)”；保存后生效"
    }

    func resetToChineseDefault() {
        config = .chineseDefault
        selectedLayer = 0
        userMessage = "已恢复中文默认配置；保存后生效"
    }

    func importConfig() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "选择 Xbox Micro / OpenMicro 配置文件"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            config = try store.importConfig(from: url)
            selectedLayer = 0
            userMessage = "配置已导入；保存后生效"
        } catch {
            errorMessage = "导入失败：\(error.localizedDescription)"
        }
    }

    func exportConfig() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "xbox-micro-config.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try store.export(config, to: url)
            userMessage = "配置已导出到 \(url.lastPathComponent)"
        } catch {
            errorMessage = "导出失败：\(error.localizedDescription)"
        }
    }

    func revealConfig() {
        NSWorkspace.shared.activateFileViewerSelecting([store.url])
    }

    func openCodex() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    func refreshDiagnostics() {
        accessibilityTrusted = AXIsProcessTrusted()
        codexInstalled = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.openai.codex") != nil
        let hooksURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex/hooks.json")
        hooksInstalled = (try? String(contentsOf: hooksURL, encoding: .utf8))
            .map { $0.contains("X-Openmicro-Instance-Id") || $0.contains("127.0.0.1:48762/om-hook") } ?? false
        loginItemEnabled = SMAppService.mainApp.status == .enabled
    }

    func requestAccessibility() {
        // The public constant has this stable string value; spelling it directly
        // avoids Swift 6 treating the imported C global as shared mutable state.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.refreshDiagnostics()
        }
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    func openCodexHooks() {
        openCodex()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("/hooks", forType: .string)
        userMessage = "已打开 Codex，并复制 /hooks；请在输入框粘贴后信任 Xbox Micro hooks"
    }

    func setLoginItem(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            refreshDiagnostics()
        } catch {
            errorMessage = "登录启动设置失败：\(error.localizedDescription)"
            refreshDiagnostics()
        }
    }
}
