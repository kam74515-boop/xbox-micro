import SwiftUI
import XboxMicroCore

struct DashboardView: View {
    @ObservedObject var model: AppModel

    private let columns = [GridItem(.adaptive(minimum: 210), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    title: "状态总览",
                    subtitle: "用 Xbox 手柄直接控制 Codex，并实时查看引擎、手柄和 Agent 状态。"
                )

                LazyVGrid(columns: columns, spacing: 14) {
                    StatusPill(
                        title: "控制引擎",
                        value: model.engine.isRunning ? "运行中" : "已停止",
                        symbol: model.engine.isRunning ? "bolt.fill" : "bolt.slash",
                        color: model.engine.isRunning ? .green : .secondary
                    )
                    StatusPill(
                        title: "游戏手柄",
                        value: model.engine.controllerConnected ? controllerName : "等待连接",
                        symbol: model.engine.controllerConnected ? "gamecontroller.fill" : "gamecontroller",
                        color: model.engine.controllerConnected ? .green : .orange
                    )
                    StatusPill(
                        title: "Agent 状态",
                        value: agentLabel,
                        symbol: "sparkles",
                        color: toneColor(model.engine.agentState.components(separatedBy: ",").first ?? "idle")
                    )
                    StatusPill(
                        title: "最近动作",
                        value: model.engine.lastAction,
                        symbol: "cursorarrow.click.2",
                        color: .purple
                    )
                }

                if let error = model.engine.launchError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }

                SectionCard("立即使用", subtitle: "默认“Codex 全功能”交互；可在按键映射中改动每一个控制项。") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                        ForEach(primaryInteractions, id: \.0) { item in
                            HStack(spacing: 12) {
                                Text(item.0)
                                    .font(.subheadline.bold().monospaced())
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.55)
                                    .frame(width: 44, height: 36)
                                    .background(item.2.opacity(0.14), in: Circle())
                                    .foregroundStyle(item.2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.1).font(.headline)
                                    Text(item.3).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                SectionCard("实时活动", subtitle: "最多保留本次运行的最近 200 条引擎事件；提示词正文不会写入日志。") {
                    if model.engine.activities.isEmpty {
                        ContentUnavailableView("暂无活动", systemImage: "waveform.path", description: Text("启动引擎并操作手柄后，这里会显示连接、动作和 Agent 状态。"))
                            .frame(height: 180)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(model.engine.activities.prefix(30)) { entry in
                                HStack(alignment: .top, spacing: 12) {
                                    Circle().fill(toneColor(entry.tone)).frame(width: 8, height: 8).padding(.top, 6)
                                    Text(entry.date, style: .time).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    Text(entry.message).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .padding(.vertical, 9)
                                if entry.id != model.engine.activities.prefix(30).last?.id { Divider() }
                            }
                        }
                    }
                }
            }
            .padding(28)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var controllerName: String {
        switch model.engine.controllerType {
        case "xbox": "Xbox 手柄"
        case "dualsense": "DualSense 手柄"
        case "dualshock4": "DualShock 4"
        case let value?: value
        case nil: "已连接"
        }
    }

    private var agentLabel: String {
        let states = model.engine.agentState.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }
        return states.map {
            switch $0 {
            case "executing": "执行中"
            case "waiting": "等待确认"
            case "complete": "已完成"
            case "error": "发生错误"
            default: "空闲"
            }
        }.joined(separator: "、")
    }

    private var primaryInteractions: [(String, String, Color, String)] {
        [
            ("A", "接受 / 确认", .green, "提交输入或允许操作"),
            ("B", "拒绝 / 返回", .red, "取消或关闭当前操作"),
            ("Y", "按住说话", .yellow, "按住录音，松开插入文本"),
            ("X", "新建任务", .blue, "在 Codex 新建任务"),
            ("十字", "界面导航", .cyan, "移动列表和选项焦点"),
            ("左摇杆", "中文工作流", .purple, "四方向填入审查/调试/重构/测试"),
            ("右摇杆", "思考深度", .indigo, "左右调整推理强度"),
            ("Guide", "切换任务", .orange, "循环当前项目中的任务"),
        ]
    }
}
