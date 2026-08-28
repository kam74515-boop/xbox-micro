import Foundation
import SwiftUI
import XboxMicroCore

struct EngineEvent: Codable, Identifiable, Sendable {
    let source: String
    let timestamp: String
    let kind: String
    let message: String
    let tone: String
    let state: String?
    let controllerType: String?
    let control: String?
    let actionType: String?

    var id: String { "\(timestamp)-\(kind)-\(message)" }
}

struct ActivityEntry: Identifiable, Sendable {
    let id = UUID()
    let date: Date
    let message: String
    let tone: String
    let kind: String
}

struct EngineLocation: Sendable {
    let node: URL
    let cli: URL
    let workingDirectory: URL
    let bundled: Bool
}

@MainActor
final class EngineManager: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var controllerConnected = false
    @Published private(set) var controllerType: String?
    @Published private(set) var agentState = "idle"
    @Published private(set) var lastAction = "尚无操作"
    @Published private(set) var lifecycleMessage = "引擎未启动"
    @Published private(set) var activities: [ActivityEntry] = []
    @Published private(set) var launchError: String?
    @Published private(set) var engineLocation: EngineLocation?

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var stdoutBuffer = ""
    private var stderrBuffer = ""
    private var intentionalStop = false

    func start() {
        guard !isRunning, process == nil else { return }
        launchError = nil
        intentionalStop = false

        do {
            let location = try resolveEngineLocation()
            engineLocation = location

            let task = Process()
            let stdout = Pipe()
            let stderr = Pipe()
            task.executableURL = location.node
            task.arguments = [location.cli.path, "codex-app"]
            task.currentDirectoryURL = location.workingDirectory
            task.standardOutput = stdout
            task.standardError = stderr
            var environment = ProcessInfo.processInfo.environment
            environment["OPENMICRO_STATUS_JSON"] = "1"
            environment["OPENMICRO_PARENT_PID"] = String(ProcessInfo.processInfo.processIdentifier)
            task.environment = environment

            stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                Task { @MainActor [weak self] in self?.consume(data, stream: .stdout) }
            }
            stderr.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                Task { @MainActor [weak self] in self?.consume(data, stream: .stderr) }
            }
            task.terminationHandler = { [weak self] task in
                Task { @MainActor [weak self] in self?.didTerminate(exitCode: task.terminationStatus) }
            }

            try task.run()
            process = task
            stdoutPipe = stdout
            stderrPipe = stderr
            isRunning = true
            lifecycleMessage = "引擎启动中…"
            appendActivity("Xbox Micro 引擎已启动", tone: "complete", kind: "lifecycle")
        } catch {
            launchError = error.localizedDescription
            lifecycleMessage = "引擎启动失败"
            appendActivity("启动失败：\(error.localizedDescription)", tone: "error", kind: "lifecycle")
        }
    }

    func stop() {
        guard let process else { return }
        intentionalStop = true
        lifecycleMessage = "正在停止…"
        process.terminate()
    }

    func restart() {
        if process == nil {
            start()
            return
        }
        stop()
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self, self.process == nil else { return }
            self.start()
        }
    }

    private enum Stream { case stdout, stderr }

    private func consume(_ data: Data, stream: Stream) {
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        switch stream {
        case .stdout:
            stdoutBuffer.append(chunk)
            drainLines(from: &stdoutBuffer)
        case .stderr:
            stderrBuffer.append(chunk)
            drainLines(from: &stderrBuffer)
        }
    }

    private func drainLines(from buffer: inout String) {
        while let range = buffer.range(of: "\n") {
            let line = String(buffer[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            buffer.removeSubrange(...range.lowerBound)
            if !line.isEmpty { handle(line: line) }
        }
    }

    private func handle(line: String) {
        if let data = line.data(using: .utf8),
           let event = try? JSONDecoder().decode(EngineEvent.self, from: data),
           event.source == "openmicro" {
            handle(event: event)
            return
        }
        // Keep non-protocol engine diagnostics visible without interpreting them as state.
        let clean = line.replacingOccurrences(of: #"\u{001B}\[[0-9;]*m"#, with: "", options: .regularExpression)
        appendActivity(clean, tone: clean.lowercased().contains("error") ? "error" : "idle", kind: "diagnostic")
    }

    private func handle(event: EngineEvent) {
        lifecycleMessage = event.kind == "lifecycle" ? event.message : lifecycleMessage
        switch event.kind {
        case "controller":
            controllerConnected = event.state == "connected"
            controllerType = controllerConnected ? event.controllerType : nil
        case "agent":
            agentState = event.state ?? event.tone
        case "action":
            lastAction = event.message
        case "lifecycle":
            if event.state == "started" { lifecycleMessage = "引擎运行中，等待手柄连接" }
            if event.state == "client" { lifecycleMessage = "检测到另一引擎实例，当前为客户端" }
        default: break
        }
        appendActivity(event.message, tone: event.tone, kind: event.kind)
    }

    private func didTerminate(exitCode: Int32) {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil
        stdoutPipe = nil
        stderrPipe = nil
        isRunning = false
        controllerConnected = false
        controllerType = nil
        agentState = "idle"
        let wasIntentional = intentionalStop
        intentionalStop = false
        lifecycleMessage = wasIntentional ? "引擎已停止" : "引擎异常退出（代码 \(exitCode)）"
        appendActivity(lifecycleMessage, tone: wasIntentional ? "idle" : "error", kind: "lifecycle")
    }

    private func appendActivity(_ message: String, tone: String, kind: String) {
        activities.insert(.init(date: Date(), message: message, tone: tone, kind: kind), at: 0)
        if activities.count > 200 { activities.removeLast(activities.count - 200) }
    }

    private func resolveEngineLocation() throws -> EngineLocation {
        let fm = FileManager.default
        let environment = ProcessInfo.processInfo.environment
        let resources = Bundle.main.resourceURL

        if let resources {
            let cli = resources.appendingPathComponent("Engine/dist/cli.js")
            let node = resources.appendingPathComponent("Runtime/node")
            if fm.isExecutableFile(atPath: node.path), fm.fileExists(atPath: cli.path) {
                return .init(node: node, cli: cli, workingDirectory: cli.deletingLastPathComponent().deletingLastPathComponent(), bundled: true)
            }
        }

        var roots: [URL] = []
        if let override = environment["XBOX_MICRO_ENGINE_ROOT"], !override.isEmpty {
            roots.append(URL(fileURLWithPath: override, isDirectory: true))
        }
        let current = URL(fileURLWithPath: fm.currentDirectoryPath, isDirectory: true)
        roots += [current, current.deletingLastPathComponent()]

        let nodeCandidates = [
            environment["XBOX_MICRO_NODE"],
            "/opt/homebrew/bin/node",
            "/usr/local/bin/node",
            "/usr/bin/node",
        ].compactMap { $0 }.map(URL.init(fileURLWithPath:))

        guard let node = nodeCandidates.first(where: { fm.isExecutableFile(atPath: $0.path) }) else {
            throw NSError(domain: "XboxMicro", code: 1, userInfo: [NSLocalizedDescriptionKey: "找不到 Node.js 22 或更高版本。请使用打包版 App，或安装 Node.js。"])
        }
        for root in roots {
            let cli = root.appendingPathComponent("dist/cli.js")
            if fm.fileExists(atPath: cli.path) {
                return .init(node: node, cli: cli, workingDirectory: root, bundled: false)
            }
        }
        throw NSError(domain: "XboxMicro", code: 2, userInfo: [NSLocalizedDescriptionKey: "找不到 OpenMicro 引擎。开发运行时请设置 XBOX_MICRO_ENGINE_ROOT。"])
    }
}
