import SwiftUI
import XboxMicroCore

struct SettingsDataView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                PageHeader(
                    title: "设置与数据",
                    subtitle: "选择完整交互预设、管理启动方式，以及安全导入导出配置。"
                )

                SectionCard("交互体验预设", subtitle: "载入只修改当前草稿；点击右上角“保存并应用”后才会覆盖运行配置。") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                        ForEach(OpenMicroConfig.interactionPresets) { preset in
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Image(systemName: presetIcon(preset.id)).font(.title2).foregroundStyle(Color.accentColor)
                                    Text(preset.name).font(.headline)
                                }
                                Text(preset.summary).font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                Button("载入此预设") { model.applyPreset(preset) }
                                    .buttonStyle(.bordered)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
                            .background(.background, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(.separator.opacity(0.6)))
                        }
                    }
                }

                SectionCard("启动与后台运行") {
                    Toggle("打开 Xbox Micro 时自动启动控制引擎", isOn: $model.autoStartEngine)
                    Toggle("登录 macOS 时自动打开 Xbox Micro", isOn: loginItemBinding)
                    Text("关闭主窗口后，App 仍保留在菜单栏；选择菜单栏“退出 Xbox Micro”才会结束。")
                        .font(.caption).foregroundStyle(.secondary)
                }

                SectionCard("配置文件", subtitle: model.configPath) {
                    HStack {
                        Button("导入 JSON…") { model.importConfig() }
                        Button("导出 JSON…") { model.exportConfig() }
                        Button("在 Finder 中显示") { model.revealConfig() }
                        Spacer()
                        Button("恢复中文默认配置", role: .destructive) { model.resetToChineseDefault() }
                    }
                    Divider()
                    LabeledContent("映射层", value: "\(model.config.layers.count) 层")
                    LabeledContent("可映射控制项", value: "每层 \(ControlDefinition.all.count) 项")
                    LabeledContent("提示词预设", value: "\(model.config.workflows.count) 个")
                    LabeledContent("未保存更改", value: model.hasUnsavedChanges ? "有" : "无")
                }

                SectionCard("安全说明") {
                    Label("配置写入前会验证六层结构、控制项、动作参数与工作流引用。", systemImage: "checkmark.shield")
                    Label("写入采用原子替换，损坏或不完整的导入文件不会覆盖当前配置。", systemImage: "lock.doc")
                    Label("提示词正文不进入活动日志；按键日志只显示动作类型。", systemImage: "eye.slash")
                }
            }
            .padding(28)
        }
    }

    private var loginItemBinding: Binding<Bool> {
        Binding(
            get: { model.loginItemEnabled },
            set: { model.setLoginItem($0) }
        )
    }

    private func presetIcon(_ id: String) -> String {
        switch id {
        case "voice": "mic.fill"
        case "keyboard": "keyboard.fill"
        case "workflows": "wand.and.stars"
        default: "gamecontroller.fill"
        }
    }
}
