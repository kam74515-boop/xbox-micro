import SwiftUI

@MainActor
final class XboxMicroAppDelegate: NSObject, NSApplicationDelegate {
    weak var engine: EngineManager?

    func applicationWillTerminate(_ notification: Notification) {
        engine?.stop()
    }
}

@main
struct XboxMicroDesktopApp: App {
    @NSApplicationDelegateAdaptor(XboxMicroAppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup("Xbox Micro", id: "main") {
            RootView(model: model)
                .frame(minWidth: 980, minHeight: 680)
                .task {
                    appDelegate.engine = model.engine
                    model.startIfNeeded()
                }
        }
        .defaultSize(width: 1180, height: 780)

        MenuBarExtra {
            MenuBarContent(model: model)
        } label: {
            Label("Xbox Micro", systemImage: model.engine.controllerConnected ? "gamecontroller.fill" : "gamecontroller")
        }
    }
}

private struct MenuBarContent: View {
    @ObservedObject var model: AppModel
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Group {
            Label(model.engine.isRunning ? "引擎运行中" : "引擎已停止", systemImage: model.engine.isRunning ? "bolt.fill" : "bolt.slash")
            Label(
                model.engine.controllerConnected ? "手柄已连接：\(model.engine.controllerType ?? "未知")" : "等待手柄连接",
                systemImage: model.engine.controllerConnected ? "checkmark.circle.fill" : "circle.dotted"
            )
            Divider()
            Button("打开控制面板") {
                openWindow(id: "main")
                NSApplication.shared.activate(ignoringOtherApps: true)
            }
            Button(model.engine.isRunning ? "停止引擎" : "启动引擎") {
                model.engine.isRunning ? model.engine.stop() : model.engine.start()
            }
            Button("打开 Codex") { model.openCodex() }
            Divider()
            Button("退出 Xbox Micro") { NSApplication.shared.terminate(nil) }
        }
    }
}
