import Foundation
import Testing
@testable import XboxMicroCore

@Test("中文默认配置可编码并保持六层结构")
func defaultConfigRoundTrip() throws {
    let config = OpenMicroConfig.chineseDefault
    #expect(config.layers.count == 6)
    #expect(config.layers[0].bindings.count >= 18)
    #expect(config.workflows["debug"]?.contains("根因") == true)
    for (index, layer) in config.layers.enumerated() {
        #expect(layer.bindings["menu"] == .init(type: .layer, index: (index + 1) % 6))
        #expect(layer.bindings["view"] == .init(type: .layer, index: (index + 5) % 6))
        #expect(layer.bindings.count >= 6)
    }

    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(OpenMicroConfig.self, from: data)
    #expect(decoded.layers.map(\.name) == config.layers.map(\.name))
    #expect(decoded.layers[0].bindings == config.layers[0].bindings)
    #expect(decoded.workflows == config.workflows)
}

@Test("配置存储原子写入并可重新读取")
func saveAndLoad() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("XboxMicroTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ConfigStore(url: directory.appendingPathComponent("config.json"))
    var config = OpenMicroConfig.chineseDefault
    config.layers[5].name = "我的第六层"
    config.layers[5].bindings["south"] = .init(type: .prompt, text: "解释当前文件")

    try store.save(config)
    let loaded = try store.load(seedIfMissing: false)
    #expect(loaded.layers[5].name == "我的第六层")
    #expect(loaded.layers[5].bindings["south"]?.text == "解释当前文件")
}

@Test("旧版空白六层配置会安全迁移并保留第一层与提示词")
func migrateLegacyBlankLayers() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("XboxMicroMigrationTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ConfigStore(url: directory.appendingPathComponent("config.json"))
    var legacy = OpenMicroConfig.chineseDefault
    legacy.workflows["debug"] = "我的调试提示词"
    for index in legacy.layers.indices {
        legacy.layers[index].name = "Layer \(index + 1)"
        if index > 0 { legacy.layers[index].bindings = [:] }
    }
    legacy.layers[0].bindings.removeValue(forKey: "menu")
    legacy.layers[0].bindings.removeValue(forKey: "view")
    let originalSouth = legacy.layers[0].bindings["south"]
    try store.save(legacy)

    let migrated = try store.load(seedIfMissing: false)
    #expect(migrated.layers.map(\.name) == ["Codex 主控", "语音与提示", "代码审查", "调试与测试", "任务导航", "自定义"])
    #expect(migrated.layers[0].bindings["south"] == originalSouth)
    #expect(migrated.layers[0].bindings["menu"] == .init(type: .layer, index: 1))
    #expect(migrated.layers[5].bindings["view"] == .init(type: .layer, index: 4))
    #expect(migrated.workflows["debug"] == "我的调试提示词")

    let persisted = try JSONDecoder().decode(OpenMicroConfig.self, from: Data(contentsOf: store.url))
    #expect(persisted.layers[1].bindings.isEmpty == false)
}

@Test("无效结构不会通过验证")
func rejectInvalidConfig() throws {
    let store = ConfigStore(url: URL(fileURLWithPath: "/tmp/not-used-xbox-micro.json"))
    var config = OpenMicroConfig.chineseDefault
    config.layers.removeLast()
    #expect(throws: ConfigError.invalidLayerCount(5)) { try store.validate(config) }

    config = .chineseDefault
    config.layers[0].bindings["unknown"] = .init(type: .accept)
    #expect(throws: ConfigError.unknownControl("unknown")) { try store.validate(config) }

    config = .chineseDefault
    config.layers[0].bindings["south"] = .init(type: .layer, index: 9)
    #expect(throws: ConfigError.invalidAction("映射层必须为 1…6")) { try store.validate(config) }
}

@Test("键盘控制字符的可见编辑格式可无损往返")
func keySequenceRoundTrip() throws {
    let raw = "\u{1B}[109;6u\r\t\\"
    let visible = KeySequenceCodec.display(raw)
    #expect(visible == "\\x1B[109;6u\\r\\t\\\\")
    #expect(try KeySequenceCodec.parse(visible) == raw)
    #expect(throws: ConfigError.invalidKeySequence("\\x 后需要两位十六进制数")) {
        try KeySequenceCodec.parse("\\xA")
    }
}

@Test("所有交互预设均是完整且有效的六层配置")
func presetsValidate() throws {
    let store = ConfigStore(url: URL(fileURLWithPath: "/tmp/not-used-xbox-micro.json"))
    #expect(OpenMicroConfig.interactionPresets.count == 4)
    for preset in OpenMicroConfig.interactionPresets {
        try store.validate(preset.config)
        #expect(preset.config.layers.count == 6)
        #expect(!preset.config.layers[0].bindings.isEmpty)
    }
}
