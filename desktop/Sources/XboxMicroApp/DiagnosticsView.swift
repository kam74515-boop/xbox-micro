import SwiftUI

struct DiagnosticsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    title: "诊断与权限",
                    subtitle: "检查 Codex、系统辅助功能、Hooks、引擎位置和当前连接。"
                )

                SectionCard("必需条件") {
                    DiagnosticRow(
                        title: "Codex 桌面 App",
                        detail: model.codexInstalled ? "已安装，可由手柄激活和控制" : "未找到 com.openai.codex",
                        passed: model.codexInstalled,
                        actionTitle: model.codexInstalled ? "打开 Codex" : nil,
                        action: model.openCodex
                    )
                    Divider()
                    DiagnosticRow(
                        title: "辅助功能权限",
                        detail: model.accessibilityTrusted ? "已允许模拟键盘输入" : "需要允许 Xbox Micro 控制键盘输入",
                        passed: model.accessibilityTrusted,
                        actionTitle: model.accessibilityTrusted ? "系统设置" : "请求权限",
                        action: model.accessibilityTrusted ? model.openAccessibilitySettings : model.requestAccessibility
                    )
                    Divider()
                    DiagnosticRow(
                        title: "Codex 生命周期 Hooks",
                        detail: model.hooksInstalled ? "已注册；Codex 中还需信任定义" : "引擎首次启动时会自动注册",
                        passed: model.hooksInstalled,
                        actionTitle: "打开 /hooks",
                        action: model.openCodexHooks
                    )
                }

                SectionCard("运行时") {
                    KeyValueRow("引擎", model.engine.isRunning ? "运行中" : "已停止")
                    KeyValueRow("生命周期", model.engine.lifecycleMessage)
                    KeyValueRow("手柄", model.engine.controllerConnected ? "已连接 · \(model.engine.controllerType ?? "未知型号")" : "未连接")
                    KeyValueRow("Agent", model.engine.agentState)
                    if let location = model.engine.engineLocation {
                        KeyValueRow("运行方式", location.bundled ? "App 内置引擎" : "开发目录引擎")
                        KeyValueRow("Node", location.node.path)
                        KeyValueRow("CLI", location.cli.path)
                    }
                    if let error = model.engine.launchError {
                        KeyValueRow("启动错误", error, color: .red)
                    }
                }

                SectionCard("修复入口", subtitle: "macOS 可能分别要求辅助功能和自动化权限；修改权限后返回此页刷新。") {
                    HStack {
                        Button("刷新检查") { model.refreshDiagnostics() }
                            .buttonStyle(.borderedProminent)
                        Button("打开辅助功能设置") { model.openAccessibilitySettings() }
                        Button("打开自动化设置") { model.openAutomationSettings() }
                        Button("重启引擎") { model.engine.restart() }
                            .disabled(!model.engine.isRunning)
                    }
                }

                SectionCard("诊断日志", subtitle: "原始提示词和键盘字节不会显示。") {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(model.engine.activities) { entry in
                                HStack(alignment: .top) {
                                    Text(entry.date, style: .time).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                                    Text(entry.message).font(.caption.monospaced()).textSelection(.enabled)
                                    Spacer()
                                }
                            }
                        }
                    }
                    .frame(minHeight: 180, maxHeight: 320)
                    .padding(12)
                    .background(.black.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(28)
        }
    }
}

private struct DiagnosticRow: View {
    let title: String
    let detail: String
    let passed: Bool
    let actionTitle: String?
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: passed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(passed ? .green : .orange)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            if let actionTitle { Button(actionTitle, action: action) }
        }
        .padding(.vertical, 4)
    }
}

private struct KeyValueRow: View {
    let key: String
    let value: String
    let color: Color

    init(_ key: String, _ value: String, color: Color = .primary) {
        self.key = key
        self.value = value
        self.color = color
    }

    var body: some View {
        LabeledContent(key) {
            Text(value).foregroundStyle(color).textSelection(.enabled)
        }
        Divider()
    }
}
