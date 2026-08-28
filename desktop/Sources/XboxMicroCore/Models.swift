import Foundation

public struct RGBColor: Codable, Equatable, Sendable {
    public var r: Double
    public var g: Double
    public var b: Double

    public init(r: Double, g: Double, b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }
}

public enum ActionKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case accept
    case reject
    case pushToTalk = "push_to_talk"
    case newChat = "new_chat"
    case thinkingDepth = "thinking_depth"
    case workflow
    case prompt
    case focusSession = "focus_session"
    case layer
    case herdrSpace = "herdr_space"
    case keys

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .accept: "接受 / 确认"
        case .reject: "拒绝 / 返回"
        case .pushToTalk: "按住说话"
        case .newChat: "新建任务"
        case .thinkingDepth: "调整思考深度"
        case .workflow: "填入工作流预设"
        case .prompt: "填入自定义提示词"
        case .focusSession: "切换任务"
        case .layer: "切换映射层"
        case .herdrSpace: "切换 Herdr 工作区"
        case .keys: "发送键盘按键"
        }
    }

    public var symbol: String {
        switch self {
        case .accept: "checkmark.circle"
        case .reject: "xmark.circle"
        case .pushToTalk: "mic"
        case .newChat: "plus.bubble"
        case .thinkingDepth: "brain"
        case .workflow: "wand.and.stars"
        case .prompt: "text.bubble"
        case .focusSession: "rectangle.3.group"
        case .layer: "square.3.layers.3d"
        case .herdrSpace: "square.grid.2x2"
        case .keys: "keyboard"
        }
    }
}

/// Mirrors the OpenMicro discriminated Action union. Only fields used by `type` are encoded.
public struct ActionBinding: Codable, Equatable, Sendable {
    public var type: ActionKind
    public var delta: Int?
    public var presetId: String?
    public var text: String?
    public var index: Int?
    public var bytes: String?

    public init(
        type: ActionKind,
        delta: Int? = nil,
        presetId: String? = nil,
        text: String? = nil,
        index: Int? = nil,
        bytes: String? = nil
    ) {
        self.type = type
        self.delta = delta
        self.presetId = presetId
        self.text = text
        self.index = index
        self.bytes = bytes
    }

    public static func defaultValue(for kind: ActionKind, workflows: [String: String]) -> Self {
        switch kind {
        case .thinkingDepth: .init(type: kind, delta: 1)
        case .workflow: .init(type: kind, presetId: workflows.keys.sorted().first ?? "review-pr")
        case .prompt: .init(type: kind, text: "请输入要发送给 Agent 的提示词")
        case .focusSession: .init(type: kind, index: -1)
        case .layer: .init(type: kind, index: 0)
        case .keys: .init(type: kind, bytes: "\r")
        default: .init(type: kind)
        }
    }

    private enum CodingKeys: String, CodingKey {
        case type, delta, presetId, text, index, bytes
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        switch type {
        case .thinkingDepth: try container.encode(delta ?? 1, forKey: .delta)
        case .workflow: try container.encode(presetId ?? "", forKey: .presetId)
        case .prompt: try container.encode(text ?? "", forKey: .text)
        case .focusSession, .layer: try container.encode(index ?? 0, forKey: .index)
        case .keys: try container.encode(bytes ?? "", forKey: .bytes)
        default: break
        }
    }
}

public struct MappingLayer: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var name: String
    public var color: RGBColor
    public var bindings: [String: ActionBinding]

    public init(name: String, color: RGBColor, bindings: [String: ActionBinding]) {
        self.name = name
        self.color = color
        self.bindings = bindings
    }

    private enum CodingKeys: String, CodingKey { case name, color, bindings }
}

public struct OpenMicroConfig: Codable, Equatable, Sendable {
    public var layers: [MappingLayer]
    public var workflows: [String: String]

    public init(layers: [MappingLayer], workflows: [String: String]) {
        self.layers = layers
        self.workflows = workflows
    }
}

public struct ControlDefinition: Identifiable, Hashable, Sendable {
    public enum Group: String, CaseIterable, Sendable {
        case face = "正面按键"
        case dpad = "方向键"
        case shoulder = "肩键与菜单"
        case leftStick = "左摇杆手势"
        case rightStick = "右摇杆手势"
    }

    public let id: String
    public let label: String
    public let shortLabel: String
    public let group: Group

    public init(_ id: String, _ label: String, _ shortLabel: String, _ group: Group) {
        self.id = id
        self.label = label
        self.shortLabel = shortLabel
        self.group = group
    }

    public static let all: [Self] = [
        .init("south", "A / 底部按键", "A", .face),
        .init("east", "B / 右侧按键", "B", .face),
        .init("west", "X / 左侧按键", "X", .face),
        .init("north", "Y / 顶部按键", "Y", .face),
        .init("dpad_up", "方向键 上", "↑", .dpad),
        .init("dpad_down", "方向键 下", "↓", .dpad),
        .init("dpad_left", "方向键 左", "←", .dpad),
        .init("dpad_right", "方向键 右", "→", .dpad),
        .init("l1", "LB / L1", "LB", .shoulder),
        .init("r1", "RB / R1", "RB", .shoulder),
        .init("l2", "LT / L2", "LT", .shoulder),
        .init("r2", "RT / R2", "RT", .shoulder),
        .init("l3", "按下左摇杆", "L3", .shoulder),
        .init("r3", "按下右摇杆", "R3", .shoulder),
        .init("menu", "菜单键", "☰", .shoulder),
        .init("view", "视图键", "▣", .shoulder),
        .init("touchpad", "触摸板 / Guide", "◉", .shoulder),
        .init("lstick_up", "左摇杆 上甩", "L↑", .leftStick),
        .init("lstick_down", "左摇杆 下甩", "L↓", .leftStick),
        .init("lstick_left", "左摇杆 左甩", "L←", .leftStick),
        .init("lstick_right", "左摇杆 右甩", "L→", .leftStick),
        .init("lstick_cw", "左摇杆 顺时针", "L↻", .leftStick),
        .init("lstick_ccw", "左摇杆 逆时针", "L↺", .leftStick),
        .init("rstick_up", "右摇杆 上甩", "R↑", .rightStick),
        .init("rstick_down", "右摇杆 下甩", "R↓", .rightStick),
        .init("rstick_left", "右摇杆 左甩", "R←", .rightStick),
        .init("rstick_right", "右摇杆 右甩", "R→", .rightStick),
        .init("rstick_cw", "右摇杆 顺时针", "R↻", .rightStick),
        .init("rstick_ccw", "右摇杆 逆时针", "R↺", .rightStick),
    ]

    public static let ids = Set(all.map(\.id))
}

public struct InteractionPreset: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let summary: String
    public let config: OpenMicroConfig
}

public extension OpenMicroConfig {
    static let chineseWorkflows: [String: String] = [
        "review-pr": "审查当前 PR 的正确性、安全性和代码风格问题。请引用文件路径和行号，并明确指出任何不确定之处。",
        "debug": "帮我调试当前问题。先询问具体的故障现象以及我已经尝试过的方法，然后调查根因，再提出修复方案。",
        "refactor": "在不改变现有行为的前提下重构当前代码，使其更清晰、更简洁。说明每项改动，并保持最小必要差异。",
        "write-tests": "为当前代码编写测试，覆盖正常路径以及最可能在生产环境中出错的边界情况。",
    ]

    private static let colors: [RGBColor] = [
        .init(r: 255, g: 255, b: 255),
        .init(r: 160, g: 32, b: 240),
        .init(r: 0, g: 255, b: 255),
        .init(r: 255, g: 140, b: 0),
        .init(r: 255, g: 20, b: 147),
        .init(r: 255, g: 255, b: 0),
    ]

    static var chineseDefault: Self {
        let face: [String: ActionBinding] = [
            "south": .init(type: .accept),
            "east": .init(type: .reject),
            "north": .init(type: .pushToTalk),
            "west": .init(type: .newChat),
        ]
        let dpad: [String: ActionBinding] = [
            "dpad_up": .init(type: .keys, bytes: "\u{1B}[A"),
            "dpad_down": .init(type: .keys, bytes: "\u{1B}[B"),
            "dpad_right": .init(type: .keys, bytes: "\u{1B}[C"),
            "dpad_left": .init(type: .keys, bytes: "\u{1B}[D"),
        ]
        func makeLayer(
            _ index: Int,
            _ name: String,
            _ bindings: [String: ActionBinding]
        ) -> MappingLayer {
            let navigation: [String: ActionBinding] = [
                "menu": .init(type: .layer, index: (index + 1) % 6),
                "view": .init(type: .layer, index: (index + 5) % 6),
            ]
            return MappingLayer(
                name: name,
                color: colors[index],
                bindings: navigation.merging(bindings) { _, specific in specific }
            )
        }

        let primary = makeLayer(0, "Codex 主控", face.merging(dpad) { _, action in action }.merging([
            "r1": .init(type: .keys, bytes: "\u{1B}[Z"),
            "r2": .init(type: .keys, bytes: "\u{15}"),
            "lstick_up": .init(type: .workflow, presetId: "review-pr"),
            "lstick_down": .init(type: .workflow, presetId: "debug"),
            "lstick_left": .init(type: .workflow, presetId: "refactor"),
            "lstick_right": .init(type: .workflow, presetId: "write-tests"),
            "l2": .init(type: .herdrSpace),
            "rstick_right": .init(type: .thinkingDepth, delta: 1),
            "rstick_left": .init(type: .thinkingDepth, delta: -1),
            "r3": .init(type: .keys, bytes: "\u{1B}[109;6u"),
            "touchpad": .init(type: .focusSession, index: -1),
        ]) { _, action in action })

        let voice = makeLayer(1, "语音与提示", face.merging(dpad) { _, action in action }.merging([
            "l1": .init(type: .workflow, presetId: "review-pr"),
            "r1": .init(type: .workflow, presetId: "debug"),
            "l2": .init(type: .workflow, presetId: "refactor"),
            "r2": .init(type: .workflow, presetId: "write-tests"),
            "l3": .init(type: .prompt, text: "总结当前任务的进展、风险和下一步。"),
            "r3": .init(type: .prompt, text: "解释当前屏幕中的结果，并告诉我应该选择什么。"),
            "touchpad": .init(type: .focusSession, index: -1),
        ]) { _, action in action })

        let review = makeLayer(2, "代码审查", face.merging(dpad) { _, action in action }.merging([
            "west": .init(type: .workflow, presetId: "review-pr"),
            "l1": .init(type: .prompt, text: "仅检查当前改动中的安全漏洞、权限边界和敏感数据风险。"),
            "r1": .init(type: .prompt, text: "审查未提交改动，按严重程度列出问题并引用文件与行号。"),
            "l2": .init(type: .prompt, text: "列出当前改动最可能导致回归的三个风险。"),
            "r2": .init(type: .prompt, text: "基于审查结果生成最小修复计划，暂时不要修改代码。"),
            "lstick_left": .init(type: .workflow, presetId: "refactor"),
            "lstick_right": .init(type: .workflow, presetId: "write-tests"),
            "touchpad": .init(type: .focusSession, index: -1),
        ]) { _, action in action })

        let debug = makeLayer(3, "调试与测试", face.merging(dpad) { _, action in action }.merging([
            "west": .init(type: .workflow, presetId: "debug"),
            "l1": .init(type: .workflow, presetId: "debug"),
            "r1": .init(type: .workflow, presetId: "write-tests"),
            "l2": .init(type: .workflow, presetId: "refactor"),
            "r2": .init(type: .workflow, presetId: "review-pr"),
            "lstick_up": .init(type: .prompt, text: "运行最相关的测试并解释第一个失败的根因。"),
            "lstick_down": .init(type: .prompt, text: "检查日志和错误堆栈，提取最早的有效失败信号。"),
            "touchpad": .init(type: .focusSession, index: -1),
        ]) { _, action in action })

        let navigation = makeLayer(4, "任务导航", face.merging(dpad) { _, action in action }.merging([
            "l1": .init(type: .keys, bytes: "\u{1B}[Z"),
            "r1": .init(type: .keys, bytes: "\t"),
            "l2": .init(type: .herdrSpace),
            "r2": .init(type: .keys, bytes: "\u{15}"),
            "rstick_right": .init(type: .thinkingDepth, delta: 1),
            "rstick_left": .init(type: .thinkingDepth, delta: -1),
            "touchpad": .init(type: .focusSession, index: -1),
        ]) { _, action in action })

        let custom = makeLayer(5, "自定义", face)
        return .init(layers: [primary, voice, review, debug, navigation, custom], workflows: chineseWorkflows)
    }

    static var interactionPresets: [InteractionPreset] {
        var voice = chineseDefault
        voice.layers[0].name = "语音优先"
        voice.layers[0].bindings["l1"] = .init(type: .pushToTalk)
        voice.layers[0].bindings["north"] = .init(type: .workflow, presetId: "review-pr")

        var keyboard = chineseDefault
        keyboard.layers[0].name = "键盘导航"
        keyboard.layers[0].bindings["l1"] = .init(type: .keys, bytes: "\t")
        keyboard.layers[0].bindings["r1"] = .init(type: .keys, bytes: "\u{1B}[Z")
        keyboard.layers[0].bindings["l3"] = .init(type: .accept)
        keyboard.layers[0].bindings["r3"] = .init(type: .reject)

        var workflows = chineseDefault
        workflows.layers[0].name = "工作流面板"
        workflows.layers[0].bindings["south"] = .init(type: .workflow, presetId: "review-pr")
        workflows.layers[0].bindings["east"] = .init(type: .workflow, presetId: "debug")
        workflows.layers[0].bindings["west"] = .init(type: .workflow, presetId: "refactor")
        workflows.layers[0].bindings["north"] = .init(type: .workflow, presetId: "write-tests")

        return [
            .init(id: "codex", name: "Codex 全功能", summary: "确认、拒绝、语音、新任务、思考深度、任务/项目切换与四个中文工作流。", config: chineseDefault),
            .init(id: "voice", name: "语音优先", summary: "LB 按住说话，Y 快速填入审查提示，适合离键盘协作。", config: voice),
            .init(id: "keyboard", name: "键盘导航", summary: "补齐 Tab、Shift-Tab、Return、Escape，适合界面选择与权限确认。", config: keyboard),
            .init(id: "workflows", name: "中文工作流", summary: "ABXY 直接填入审查、调试、重构与测试提示词。", config: workflows),
        ]
    }
}

public enum KeySequenceCodec {
    public static func display(_ value: String) -> String {
        value.unicodeScalars.map { scalar in
            switch scalar.value {
            case 0x1B: "\\x1B"
            case 0x0D: "\\r"
            case 0x0A: "\\n"
            case 0x09: "\\t"
            case 0x00...0x1F: String(format: "\\x%02X", scalar.value)
            case 0x5C: "\\\\"
            default: String(scalar)
            }
        }.joined()
    }

    public static func parse(_ value: String) throws -> String {
        var output = ""
        var index = value.startIndex
        while index < value.endIndex {
            guard value[index] == "\\" else {
                output.append(value[index])
                index = value.index(after: index)
                continue
            }
            let next = value.index(after: index)
            guard next < value.endIndex else { throw ConfigError.invalidKeySequence("结尾的反斜杠不完整") }
            switch value[next] {
            case "r": output.append("\r"); index = value.index(after: next)
            case "n": output.append("\n"); index = value.index(after: next)
            case "t": output.append("\t"); index = value.index(after: next)
            case "\\": output.append("\\"); index = value.index(after: next)
            case "x":
                let h1 = value.index(after: next)
                guard h1 < value.endIndex else { throw ConfigError.invalidKeySequence("\\x 后需要两位十六进制数") }
                let h2 = value.index(after: h1)
                guard h2 < value.endIndex else { throw ConfigError.invalidKeySequence("\\x 后需要两位十六进制数") }
                let end = value.index(after: h2)
                let hex = String(value[h1..<end])
                guard let byte = UInt8(hex, radix: 16) else {
                    throw ConfigError.invalidKeySequence("无效十六进制转义 \\x\(hex)")
                }
                output.unicodeScalars.append(UnicodeScalar(byte))
                index = end
            default: throw ConfigError.invalidKeySequence("不支持的转义 \\(value[next])")
            }
        }
        return output
    }
}
