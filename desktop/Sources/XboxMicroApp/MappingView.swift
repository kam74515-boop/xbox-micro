import SwiftUI
import XboxMicroCore

struct MappingView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(
                    title: "按键映射",
                    subtitle: "六个独立映射层，共 29 个可配置按键与摇杆手势。"
                )
                layerPicker
                layerSettings
            }
            .padding(28)

            Divider()

            List {
                ForEach(ControlDefinition.Group.allCases, id: \.rawValue) { group in
                    Section(group.rawValue) {
                        ForEach(ControlDefinition.all.filter { $0.group == group }) { control in
                            BindingRow(model: model, layerIndex: model.selectedLayer, control: control)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
    }

    private var layerPicker: some View {
        HStack(spacing: 10) {
            ForEach(model.config.layers.indices, id: \.self) { index in
                Button {
                    model.selectedLayer = index
                } label: {
                    HStack(spacing: 8) {
                        Circle().fill(model.config.layers[index].color.swiftUIColor).frame(width: 10, height: 10)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("第 \(index + 1) 层").font(.caption).foregroundStyle(.secondary)
                            Text(model.config.layers[index].name).lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .background(model.selectedLayer == index ? Color.accentColor.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(model.selectedLayer == index ? Color.accentColor : Color.secondary.opacity(0.25)))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var layerSettings: some View {
        HStack(spacing: 16) {
            TextField("映射层名称", text: $model.config.layers[model.selectedLayer].name)
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 280)
            ColorPicker("灯光颜色", selection: layerColor, supportsOpacity: false)
            Spacer()
            Text("已映射 \(model.config.layers[model.selectedLayer].bindings.count) / \(ControlDefinition.all.count)")
                .foregroundStyle(.secondary)
            Menu("复制其他层") {
                ForEach(model.config.layers.indices.filter { $0 != model.selectedLayer }, id: \.self) { index in
                    Button("从第 \(index + 1) 层 · \(model.config.layers[index].name) 复制") {
                        model.config.layers[model.selectedLayer].bindings = model.config.layers[index].bindings
                    }
                }
            }
            Button("清空当前层") {
                let navigation = model.config.layers[model.selectedLayer].bindings.filter {
                    $0.key == "menu" || $0.key == "view"
                }
                model.config.layers[model.selectedLayer].bindings = navigation
            }
            .help("保留菜单键和视图键的层间切换，清除其余映射")
        }
    }

    private var layerColor: Binding<Color> {
        Binding(
            get: { model.config.layers[model.selectedLayer].color.swiftUIColor },
            set: { model.config.layers[model.selectedLayer].color = XboxMicroCore.RGBColor($0) }
        )
    }
}

private struct BindingRow: View {
    @ObservedObject var model: AppModel
    let layerIndex: Int
    let control: ControlDefinition
    @State private var keySequenceError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                Text(control.shortLabel)
                    .font(.headline.monospaced())
                    .frame(width: 44, height: 32)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                Text(control.label).frame(width: 170, alignment: .leading)
                Picker("动作", selection: kindSelection) {
                    Text("未映射").tag("none")
                    Divider()
                    ForEach(ActionKind.allCases) { kind in
                        Label(kind.label, systemImage: kind.symbol).tag(kind.rawValue)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 290)
                Spacer()
                if action != nil {
                    Button(role: .destructive) { action = nil } label: {
                        Label("清除", systemImage: "trash")
                    }
                    .labelStyle(.iconOnly)
                }
            }
            parameterEditor
                .padding(.leading, 228)
        }
        .padding(.vertical, 5)
    }

    private var action: ActionBinding? {
        get { model.config.layers[layerIndex].bindings[control.id] }
        nonmutating set { model.config.layers[layerIndex].bindings[control.id] = newValue }
    }

    private var kindSelection: Binding<String> {
        Binding(
            get: { action?.type.rawValue ?? "none" },
            set: { raw in
                guard raw != "none", let kind = ActionKind(rawValue: raw) else {
                    action = nil
                    return
                }
                if action?.type != kind {
                    action = .defaultValue(for: kind, workflows: model.config.workflows)
                }
            }
        )
    }

    @ViewBuilder
    private var parameterEditor: some View {
        if let current = action {
            switch current.type {
            case .thinkingDepth:
                Picker("调整方向", selection: actionInt(\.delta, default: 1)) {
                    Text("降低一级").tag(-1)
                    Text("提高一级").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            case .workflow:
                HStack {
                    Picker("工作流", selection: actionString(\.presetId, default: model.config.workflows.keys.sorted().first ?? "")) {
                        ForEach(model.config.workflows.keys.sorted(), id: \.self) { id in Text(id).tag(id) }
                    }
                    Button("编辑提示词") { model.selection = .workflows }
                }
                .frame(maxWidth: 520)
            case .prompt:
                TextField("自定义提示词", text: actionString(\.text, default: ""), axis: .vertical)
                    .lineLimit(2...5)
                    .textFieldStyle(.roundedBorder)
            case .focusSession:
                HStack {
                    Stepper("任务索引：\(current.index ?? -1)", value: actionInt(\.index, default: -1), in: -1...9)
                    Text("-1 表示循环下一个").foregroundStyle(.secondary)
                }
            case .layer:
                Picker("目标映射层", selection: actionInt(\.index, default: 0)) {
                    ForEach(0..<6) { index in Text("第 \(index + 1) 层").tag(index) }
                }
                .frame(maxWidth: 260)
            case .keys:
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Picker("常用按键", selection: keyPresetSelection) {
                            Text("自定义序列").tag("custom")
                            ForEach(KeyPreset.all) { preset in Text(preset.name).tag(preset.id) }
                        }
                        .frame(maxWidth: 260)
                        TextField("例如 \\x1B[A", text: escapedBytes)
                            .font(.body.monospaced())
                            .textFieldStyle(.roundedBorder)
                    }
                    if let keySequenceError {
                        Text(keySequenceError).font(.caption).foregroundStyle(.red)
                    } else {
                        Text("支持 \\xNN、\\r、\\n、\\t 和 \\\\；原始控制字符会安全写入 JSON。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            default:
                EmptyView()
            }
        }
    }

    private func actionInt(_ keyPath: WritableKeyPath<ActionBinding, Int?>, default fallback: Int) -> Binding<Int> {
        Binding(
            get: { action?[keyPath: keyPath] ?? fallback },
            set: { value in
                guard var updated = action else { return }
                updated[keyPath: keyPath] = value
                action = updated
            }
        )
    }

    private func actionString(_ keyPath: WritableKeyPath<ActionBinding, String?>, default fallback: String) -> Binding<String> {
        Binding(
            get: { action?[keyPath: keyPath] ?? fallback },
            set: { value in
                guard var updated = action else { return }
                updated[keyPath: keyPath] = value
                action = updated
            }
        )
    }

    private var escapedBytes: Binding<String> {
        Binding(
            get: { KeySequenceCodec.display(action?.bytes ?? "") },
            set: { value in
                do {
                    let parsed = try KeySequenceCodec.parse(value)
                    guard var updated = action else { return }
                    updated.bytes = parsed
                    action = updated
                    keySequenceError = nil
                } catch {
                    keySequenceError = error.localizedDescription
                }
            }
        )
    }

    private var keyPresetSelection: Binding<String> {
        Binding(
            get: {
                guard let bytes = action?.bytes else { return "custom" }
                return KeyPreset.all.first(where: { $0.bytes == bytes })?.id ?? "custom"
            },
            set: { id in
                guard let preset = KeyPreset.all.first(where: { $0.id == id }), var updated = action else { return }
                updated.bytes = preset.bytes
                action = updated
                keySequenceError = nil
            }
        )
    }
}

private struct KeyPreset: Identifiable {
    let id: String
    let name: String
    let bytes: String

    static let all: [Self] = [
        .init(id: "return", name: "Return / 回车", bytes: "\r"),
        .init(id: "escape", name: "Escape", bytes: "\u{1B}"),
        .init(id: "tab", name: "Tab", bytes: "\t"),
        .init(id: "shift-tab", name: "Shift + Tab", bytes: "\u{1B}[Z"),
        .init(id: "up", name: "方向键 上", bytes: "\u{1B}[A"),
        .init(id: "down", name: "方向键 下", bytes: "\u{1B}[B"),
        .init(id: "right", name: "方向键 右", bytes: "\u{1B}[C"),
        .init(id: "left", name: "方向键 左", bytes: "\u{1B}[D"),
        .init(id: "clear", name: "清空输入 Ctrl + U", bytes: "\u{15}"),
        .init(id: "model-picker", name: "模型选择 Ctrl + Shift + M", bytes: "\u{1B}[109;6u"),
    ]
}
