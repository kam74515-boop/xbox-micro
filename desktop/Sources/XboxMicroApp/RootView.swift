import SwiftUI

struct RootView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(SidebarItem.allCases, selection: $model.selection) { item in
                Label(item.rawValue, systemImage: item.symbol)
                    .tag(item)
            }
            .navigationTitle("Xbox Micro")
            .safeAreaInset(edge: .bottom) {
                EngineSidebarStatus(model: model)
            }
        } detail: {
            detail
                .toolbar { toolbar }
                .alert("Xbox Micro", isPresented: messagePresented) {
                    Button("好") {
                        model.userMessage = nil
                        model.errorMessage = nil
                    }
                } message: {
                    Text(model.errorMessage ?? model.userMessage ?? "")
                }
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private var detail: some View {
        switch model.selection ?? .dashboard {
        case .dashboard: DashboardView(model: model)
        case .mapping: MappingView(model: model)
        case .workflows: WorkflowsView(model: model)
        case .diagnostics: DiagnosticsView(model: model)
        case .settings: SettingsDataView(model: model)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if model.hasUnsavedChanges {
                Button("放弃更改") { model.discardChanges() }
            }
            Button("保存并应用") { model.saveAndApply() }
                .buttonStyle(.borderedProminent)
                .disabled(!model.hasUnsavedChanges)
            Button {
                model.engine.isRunning ? model.engine.stop() : model.engine.start()
            } label: {
                Label(model.engine.isRunning ? "停止" : "启动", systemImage: model.engine.isRunning ? "stop.fill" : "play.fill")
            }
        }
    }

    private var messagePresented: Binding<Bool> {
        Binding(
            get: { model.userMessage != nil || model.errorMessage != nil },
            set: { if !$0 { model.userMessage = nil; model.errorMessage = nil } }
        )
    }
}

private struct EngineSidebarStatus: View {
    @ObservedObject var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(model.engine.isRunning ? "引擎运行中" : "引擎已停止", systemImage: "bolt.fill")
                .foregroundStyle(model.engine.isRunning ? .green : .secondary)
            Label(model.engine.controllerConnected ? "手柄已连接" : "等待手柄", systemImage: "gamecontroller")
                .foregroundStyle(model.engine.controllerConnected ? .green : .secondary)
        }
        .font(.caption)
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.bar)
    }
}
