import SwiftUI
import XboxMicroCore

struct WorkflowsView: View {
    @ObservedObject var model: AppModel
    @State private var selectedWorkflow: String?
    @State private var newWorkflowID = ""

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 14) {
                PageHeader(title: "提示词预设", subtitle: "手柄可一键填入中文工作流或任意自定义提示词。")
                    .padding([.top, .horizontal], 24)

                List(selection: $selectedWorkflow) {
                    ForEach(model.config.workflows.keys.sorted(), id: \.self) { id in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(id).font(.headline.monospaced())
                            Text(model.config.workflows[id] ?? "")
                                .lineLimit(2)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .tag(id)
                    }
                }

                HStack {
                    TextField("新预设 ID", text: $newWorkflowID)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        addWorkflow()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(sanitizedNewID.isEmpty || model.config.workflows[sanitizedNewID] != nil)
                }
                .padding([.horizontal, .bottom], 16)
            }
            .frame(minWidth: 330, idealWidth: 380)

            workflowEditor
                .frame(minWidth: 460)
        }
        .onAppear {
            if selectedWorkflow == nil { selectedWorkflow = model.config.workflows.keys.sorted().first }
        }
    }

    @ViewBuilder
    private var workflowEditor: some View {
        if let id = selectedWorkflow, model.config.workflows[id] != nil {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(id).font(.title.bold().monospaced())
                            Text("绑定动作选择“填入工作流预设”后即可使用。")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("恢复中文内容") { restoreChinese(id) }
                            .disabled(OpenMicroConfig.chineseWorkflows[id] == nil)
                        Button("删除", role: .destructive) { removeWorkflow(id) }
                    }

                    SectionCard("提示词正文", subtitle: "内容只会在触发时填入 Codex 输入框；实时活动日志不会记录正文。") {
                        TextEditor(text: workflowText(id))
                            .font(.body)
                            .scrollContentBackground(.hidden)
                            .padding(10)
                            .frame(minHeight: 280)
                            .background(.background, in: RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.separator))
                    }

                    SectionCard("当前绑定") {
                        let bindings = workflowBindings(id)
                        if bindings.isEmpty {
                            Text("尚未绑定到任何控制项。前往“按键映射”选择此工作流。")
                                .foregroundStyle(.secondary)
                        } else {
                            FlowLayout(spacing: 8) {
                                ForEach(bindings, id: \.self) { label in
                                    Text(label)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(.purple.opacity(0.12), in: Capsule())
                                        .foregroundStyle(.purple)
                                }
                            }
                        }
                    }
                }
                .padding(28)
            }
        } else {
            ContentUnavailableView("选择一个提示词预设", systemImage: "text.bubble")
        }
    }

    private var sanitizedNewID: String {
        newWorkflowID.lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" }
    }

    private func addWorkflow() {
        let id = sanitizedNewID
        guard !id.isEmpty, model.config.workflows[id] == nil else { return }
        model.config.workflows[id] = "描述希望 Agent 完成的任务、约束条件和输出格式。"
        newWorkflowID = ""
        selectedWorkflow = id
    }

    private func removeWorkflow(_ id: String) {
        // Remove bindings referencing the deleted preset so the config stays valid.
        for layerIndex in model.config.layers.indices {
            let controls = model.config.layers[layerIndex].bindings.compactMap { key, action in
                action.type == .workflow && action.presetId == id ? key : nil
            }
            for control in controls { model.config.layers[layerIndex].bindings.removeValue(forKey: control) }
        }
        model.config.workflows.removeValue(forKey: id)
        selectedWorkflow = model.config.workflows.keys.sorted().first
    }

    private func restoreChinese(_ id: String) {
        guard let text = OpenMicroConfig.chineseWorkflows[id] else { return }
        model.config.workflows[id] = text
    }

    private func workflowText(_ id: String) -> Binding<String> {
        Binding(
            get: { model.config.workflows[id] ?? "" },
            set: { model.config.workflows[id] = $0 }
        )
    }

    private func workflowBindings(_ id: String) -> [String] {
        var result: [String] = []
        for (index, layer) in model.config.layers.enumerated() {
            for (controlID, action) in layer.bindings where action.type == .workflow && action.presetId == id {
                let control = ControlDefinition.all.first(where: { $0.id == controlID })?.shortLabel ?? controlID
                result.append("第 \(index + 1) 层 · \(control)")
            }
        }
        return result.sorted()
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
        let width = proposal.width ?? 600
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return (CGSize(width: width, height: y + lineHeight), points)
    }
}
