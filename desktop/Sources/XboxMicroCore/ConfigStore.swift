import Foundation

public enum ConfigError: LocalizedError, Equatable {
    case invalidLayerCount(Int)
    case emptyLayerName(Int)
    case invalidColor(Int)
    case unknownControl(String)
    case invalidAction(String)
    case invalidKeySequence(String)

    public var errorDescription: String? {
        switch self {
        case .invalidLayerCount(let count): "配置必须恰好包含 6 层，目前为 \(count) 层。"
        case .emptyLayerName(let index): "第 \(index + 1) 层名称不能为空。"
        case .invalidColor(let index): "第 \(index + 1) 层颜色必须在 0…255 之间。"
        case .unknownControl(let id): "配置含有未知控制项：\(id)。"
        case .invalidAction(let detail): "无效动作：\(detail)。"
        case .invalidKeySequence(let detail): "按键序列无效：\(detail)。"
        }
    }
}

public struct ConfigStore: Sendable {
    public let url: URL

    public init(url: URL = Self.defaultURL) {
        self.url = url
    }

    public static var defaultURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".openmicro", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    public func load(seedIfMissing: Bool = true) throws -> OpenMicroConfig {
        if !FileManager.default.fileExists(atPath: url.path) {
            let config = OpenMicroConfig.chineseDefault
            if seedIfMissing { try save(config) }
            return config
        }
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(OpenMicroConfig.self, from: data)
        try validate(config)
        if let migrated = migrateLegacyBlankLayers(config) {
            try save(migrated)
            return migrated
        }
        return config
    }

    public func save(_ config: OpenMicroConfig) throws {
        try validate(config)
        let data = try Self.encoder.encode(config)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
    }

    public func importConfig(from source: URL) throws -> OpenMicroConfig {
        let data = try Data(contentsOf: source)
        let config = try JSONDecoder().decode(OpenMicroConfig.self, from: data)
        try validate(config)
        return config
    }

    public func export(_ config: OpenMicroConfig, to destination: URL) throws {
        try validate(config)
        try Self.encoder.encode(config).write(to: destination, options: .atomic)
    }

    public func validate(_ config: OpenMicroConfig) throws {
        guard config.layers.count == 6 else { throw ConfigError.invalidLayerCount(config.layers.count) }
        for (index, layer) in config.layers.enumerated() {
            guard !layer.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ConfigError.emptyLayerName(index)
            }
            let components = [layer.color.r, layer.color.g, layer.color.b]
            guard components.allSatisfy({ $0.isFinite && (0...255).contains($0) }) else {
                throw ConfigError.invalidColor(index)
            }
            for (control, action) in layer.bindings {
                guard ControlDefinition.ids.contains(control) else { throw ConfigError.unknownControl(control) }
                try validate(action, workflows: config.workflows)
            }
        }
    }

    private func validate(_ action: ActionBinding, workflows: [String: String]) throws {
        switch action.type {
        case .thinkingDepth:
            guard action.delta == 1 || action.delta == -1 else {
                throw ConfigError.invalidAction("思考深度只能为 +1 或 -1")
            }
        case .workflow:
            let id = action.presetId ?? ""
            guard !id.isEmpty, workflows[id] != nil else {
                throw ConfigError.invalidAction("工作流 \(id.isEmpty ? "ID 为空" : id + " 不存在")")
            }
        case .prompt:
            guard action.text != nil else { throw ConfigError.invalidAction("自定义提示词缺少 text") }
        case .focusSession:
            guard action.index != nil else { throw ConfigError.invalidAction("切换任务缺少 index") }
        case .layer:
            guard let index = action.index, (0...5).contains(index) else {
                throw ConfigError.invalidAction("映射层必须为 1…6")
            }
        case .keys:
            guard action.bytes != nil else { throw ConfigError.invalidAction("键盘动作缺少 bytes") }
        default: break
        }
    }

    /// Upgrade only the exact v1 legacy shape: "Layer 1"…"Layer 6" with
    /// layers 2–6 empty. Any user-named or partially configured layer is left
    /// untouched. Layer 1 bindings and all workflow text remain user-owned.
    private func migrateLegacyBlankLayers(_ config: OpenMicroConfig) -> OpenMicroConfig? {
        guard config.layers.count == 6,
              config.layers.map(\.name) == (1...6).map({ "Layer \($0)" }),
              config.layers.dropFirst().allSatisfy({ $0.bindings.isEmpty })
        else { return nil }

        var migrated = OpenMicroConfig.chineseDefault
        migrated.workflows = config.workflows
        migrated.layers[0].color = config.layers[0].color
        migrated.layers[0].bindings = config.layers[0].bindings
        if migrated.layers[0].bindings["menu"] == nil {
            migrated.layers[0].bindings["menu"] = .init(type: .layer, index: 1)
        }
        if migrated.layers[0].bindings["view"] == nil {
            migrated.layers[0].bindings["view"] = .init(type: .layer, index: 5)
        }
        return migrated
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }()
}
