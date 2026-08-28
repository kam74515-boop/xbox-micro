<p align="center"><img src="assets/open-micro-banner.png" alt="OpenMicro connects game controllers to Claude Code and Codex CLI" width="100%"></p>

# Xbox Micro

把 Xbox 等消费级游戏手柄变成 Codex 的原生 macOS Agent 控制器。

> [!IMPORTANT]
> 本项目派生自 Stephen Leo 的开源项目 [OpenMicro](https://github.com/stephenleo/OpenMicro)，基线为 `v1.4.3` / commit [`fcde3a1`](https://github.com/stephenleo/OpenMicro/commit/fcde3a1)，继续遵循 [MIT License](LICENSE)。Xbox Micro 新增原生 SwiftUI 桌面端、六层中文交互预设、完整映射编辑、诊断、配置迁移以及 `.app` / `.dmg` 打包。详细来源与改动边界见 [NOTICE.md](NOTICE.md)。

## Xbox Micro macOS App

本仓库包含原生 SwiftUI 桌面端：菜单栏常驻、实时手柄/Agent 状态、六层完整按键映射、中文提示词预设、权限与 Hooks 诊断、登录启动，以及配置导入导出。

开发运行：

```bash
npm run build
cd desktop
XBOX_MICRO_ENGINE_ROOT="$(cd .. && pwd)" swift run XboxMicro
```

构建可安装的 `.app` 和 `.dmg`（自动下载并校验官方 Node.js arm64 运行时）：

```bash
npm run desktop:build
```

产物位于 `build/Xbox Micro.app` 与 `build/Xbox-Micro.dmg`。本地构建采用 ad-hoc 签名；跨设备分发时需要使用 Apple Developer ID 重新签名和公证。

## 项目来源与分支关系

- Xbox Micro 仓库：[kam74515-boop/xbox-micro](https://github.com/kam74515-boop/xbox-micro)
- 上游项目：[stephenleo/OpenMicro](https://github.com/stephenleo/OpenMicro)
- 上游基线：OpenMicro `v1.4.3`，commit `fcde3a1`
- 原始作者：Stephen Leo
- 授权协议：MIT；原始版权声明保留在 [LICENSE](LICENSE)
- Git 远程约定：`origin` 指向 Xbox Micro，`upstream` 指向 OpenMicro

下方保留 OpenMicro 引擎的 CLI、兼容性和扩展接口文档；Xbox Micro 桌面端直接复用并扩展该引擎。

## OpenMicro 引擎：Start in 60 seconds

You need macOS, Node.js 22 or newer, Claude Code or Codex CLI, and a connected controller. OpenMicro is macOS-first; other platforms are not yet tested.

```sh
npm i -g openmicro

openmicro claude # or just: openmicro
openmicro codex
openmicro codex-app # drive the Codex macOS desktop app
```

`openmicro codex-app` drives the Codex desktop app instead of a terminal CLI: new chat and prompt prefill use `codex://` deep links (no permission needed), while submit (Enter), reject (Esc), dictation (Ctrl+Shift+D), d-pad arrows, and Ctrl+U send keystrokes and need Accessibility permission for your terminal. A stick-flick prompt prefills the composer; press submit to send it. The app launches automatically and the terminal shows live status (controller, actions, agent state).

The thinking-depth dial (right-stick flicks) needs one-time setup: the app ships "Increase reasoning effort" and "Decrease reasoning effort" shortcuts unassigned, and assignments are account-synced so OpenMicro cannot set them for you. In the Codex app open Settings → Keyboard shortcuts, search "effort", and assign Increase to `⌃⌥=` (Control+Option+`=`, Ctrl+Alt on Windows) and Decrease to `⌃⌥-` — right-stick flicks then step the composer's reasoning effort. These chords avoid the app's Ctrl/Cmd `+`/`-` zoom shortcuts. Note the app's own Decrease shortcut stops one step short of the lowest effort level (also when pressed physically) — use the model picker for that. Optionally also assign "Open model picker" to `⌃⇧M` — right-stick click then opens the picker so you can watch the effort change. Assigned different chords? Remap `thinking_depth` in your OpenMicro config to matching `keys` bindings.

OpenMicro installs its lifecycle hooks automatically. If Codex reports that its hooks changed, open `/hooks` in Codex and trust the OpenMicro hooks.

Controller support depends on the exact device and connection. Check the [controller compatibility guide](CONTROLLERS.md) before you start, or run `openmicro doctor` to test your controller.

## Default controls

|                                   DualSense                                    |                                      GameSir G7 Pro                                      |
| :----------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------: |
| ![Default OpenMicro DualSense controls](assets/default-dualsense-controls.png) | ![Default OpenMicro GameSir G7 Pro controls](assets/default-gamesir-g7-pro-controls.png) |

### Text control reference

| Control                                   | Action                                                       |
| ----------------------------------------- | ------------------------------------------------------------ |
| south (✕ / A)                             | Submit or confirm                                            |
| east (○ / B)                              | Interrupt or dismiss                                         |
| north (△ / Y)                             | Push-to-talk                                                 |
| west (□ / X)                              | Start a new chat                                             |
| d-pad                                     | Navigate TUI menus; repeats while held                       |
| left stick flick up / down / left / right | Review PR / debug / refactor / write tests                   |
| right stick flick right / left            | Increase / decrease thinking depth                           |
| R1                                        | Cycle modes (Shift+Tab)                                      |
| R2                                        | Clear the input line (Ctrl+U)                                |
| right stick click (R3)                    | Open the model picker (Codex app, with shortcut setup)       |
| touchpad click                            | Focus the next session by default, where supported           |
| L2                                        | Cycle herdr spaces; touchpad then cycles agents in the space |

Stick flicks fire after returning to center. Rotation gestures (`rstick_cw`/`rstick_ccw`, one step per quarter-turn) remain available for remapping. Hold L1 with south, east, west, north, d-pad up, or d-pad down to select one of six layers. The first layer ships with these defaults; the other five start empty. Other controls are unbound by default and remappable.

Voice and thinking-depth support varies by harness; see [OpenMicro feature parity](#openmicro-feature-parity).

## See it in action

Animated demos (rendered, not filmed) of the six core interactions:

|                                                                                                                                            |                                                                                                                              |
| :----------------------------------------------------------------------------------------------------------------------------------------: | :--------------------------------------------------------------------------------------------------------------------------: |
| ![Lightbar status colors follow the focused session](assets/demo/status-leds.gif)<br>**Status lightbar** — executing, waiting, done, error | ![Face buttons submit, interrupt, dictate, and start a new chat](assets/demo/command-keys.gif)<br>**Command keys** — ✕ ○ △ □ |
|        ![Left-stick flick launches a workflow prompt](assets/demo/workflow-flick.gif)<br>**Workflow flick** — stick up = review PR         | ![Right-stick flicks step thinking depth](assets/demo/thinking-dial.gif)<br>**Thinking dial** — stick flicks step `/effort`  |
|                 ![L1 plus a face button switches control layers](assets/demo/layers.gif)<br>**Layers** — hold L1 to switch                 | ![Touchpad click moves focus between sessions](assets/demo/multi-session.gif)<br>**Multi-session** — touchpad switches focus |

## What it gives you

- Respond to agents without hunting through terminal tabs.
- Launch review, debug, refactor, and test workflows with a stick flick.
- Switch among active sessions from one controller.
- See focused-session state on DualSense.
- Remap six layers for project-specific workflows.
- First-class [herdr](#herdr-integration) support: sessions appear in the herdr workspace overview, and the controller drives herdr spaces and agents.

## OpenMicro feature parity

`✅` supported · `⚠️` setup required or best-effort · `—` no verified equivalent

| Capability                       | Claude Code                    | Codex CLI                    |
| -------------------------------- | ------------------------------ | ---------------------------- |
| Launch and forward CLI arguments | ✅ `openmicro claude`          | ✅ `openmicro codex`         |
| Submit / confirm                 | ✅ Enter                       | ✅ Enter                     |
| Interrupt / dismiss              | ✅ Escape                      | ✅ Escape                    |
| Start a new chat                 | ✅ `/clear`                    | ✅ `/new`                    |
| D-pad TUI navigation             | ✅ Arrow-key passthrough       | ✅ Arrow-key passthrough     |
| Stick-triggered workflow prompts | ✅ Supported                   | ✅ Supported                 |
| Push-to-talk                     | ✅ Enable with `/voice`        | — No equivalent              |
| Thinking-depth dial              | ✅ `/effort`, low → max        | — No deterministic binding   |
| Six remappable control layers    | ✅ Supported                   | ✅ Supported                 |
| Multi-session focus switching    | ✅ Supported                   | ✅ Supported                 |
| Executing status                 | ✅ Prompt and tool hooks       | ✅ Prompt and tool hooks     |
| Waiting-for-input status         | ✅ Questions and notifications | ✅ Permission requests       |
| Stop status                      | ✅ Stop hook                   | ✅ Stop hook                 |
| Error status                     | ⚠️ Notification-text matching  | — No error hook signal       |
| Hook installation                | ✅ Automatic                   | ⚠️ Trust changes in `/hooks` |

Layers, workflows, navigation, and session switching are handled by OpenMicro itself. Harness-specific gaps are left unmapped instead of sending guessed keystrokes. A Stop event means the agent stopped; it does not guarantee success.

## Configure controls and workflows

OpenMicro creates `~/.openmicro/config.json` on first run. Edit bindings, layer colors, and workflow prompt text there. Invalid configuration stops startup without overwriting the file.

```json
{
  "layers": [
    {
      "name": "Codex 主控",
      "color": { "r": 255, "g": 255, "b": 255 },
      "bindings": {
        "south": { "type": "accept" },
        "lstick_up": { "type": "workflow", "presetId": "review-pr" },
        "rstick_right": { "type": "thinking_depth", "delta": 1 }
      }
    },
    { "name": "Layer 2", "color": { "r": 160, "g": 32, "b": 240 }, "bindings": {} },
    { "name": "Layer 3", "color": { "r": 0, "g": 255, "b": 255 }, "bindings": {} },
    { "name": "Layer 4", "color": { "r": 255, "g": 140, "b": 0 }, "bindings": {} },
    { "name": "Layer 5", "color": { "r": 255, "g": 20, "b": 147 }, "bindings": {} },
    { "name": "Layer 6", "color": { "r": 255, "g": 255, "b": 0 }, "bindings": {} }
  ],
  "workflows": {
    "review-pr": "审查当前 PR 的正确性、安全性和代码风格问题。请引用文件路径和行号。"
  }
}
```

Binding keys can be buttons such as `south` and `dpad_up`, or gestures such as `lstick_up` and `rstick_cw`. Actions include `accept`, `reject`, `push_to_talk`, `new_chat`, `thinking_depth`, `workflow`, `prompt`, `focus_session`, `layer`, `herdr_space`, and raw `keys`.

## Sessions and status

The first OpenMicro process owns the controller and becomes the host. Later processes register as clients, so one controller can drive several terminal sessions. On supported pads, touchpad click cycles focus by default.

On DualSense, the lightbar follows the focused session: blue while executing, amber while waiting, green when stopped, red on a detected error, and dim white while idle. The five player LEDs show occupied session slots.

## Herdr integration

OpenMicro treats [herdr](https://github.com/stephenleo/herdr) as a first-class environment. Everything below is automatic and a no-op outside herdr or when the `herdr` CLI is absent.

- **State reporting.** A wrapped session running inside a herdr-managed pane reports its state (working/blocked/idle) to herdr, so it shows up in the herdr agents panel. OpenMicro claims the pane at startup and releases it on exit.
- **Space switching.** L2 cycles through herdr workspaces ("spaces") and back to local mode.
- **Agent cycling.** While a space is selected, the touchpad cycles focus across that space's agents instead of local sessions.
- **Focus follows herdr.** Voice and keystrokes retarget to the agent focused in herdr — switching spaces or agents never spills input into a session in another space.

## Controller compatibility

See [CONTROLLERS.md](CONTROLLERS.md) for the full list of community-tested controllers, connection-specific notes, and per-device status.

## Test or contribute a controller

```sh
openmicro doctor
```

The diagnostic checks controller input and, on DualSense, lightbar/player-LED output. It writes a `<vid>-<pid>-<transport>.json` report that can be added unchanged to `test/fixtures/controllers/`; CI then replays the captured inputs as a regression test. See [CONTROLLERS.md](CONTROLLERS.md) for contribution steps.

## Hardware notes

- DualSense is the only controller with lightbar and player-LED output. DS4, Xbox, and GameSir controllers are input-only; generic HID input is best-effort because report layouts vary.
- DualSense has five player LEDs, so feedback represents at most five active session slots.

## Add another harness

The public `openmicro/harness` API exposes the `Harness` contract and `registerHarness()`. Implement the contract, return `null` for actions without a verified CLI equivalent, and register it before OpenMicro resolves the harness.

```ts
import { registerHarness } from 'openmicro/harness'
import type { Harness } from 'openmicro/harness'

const myHarness: Harness = {
  kind: 'my-cli',
  command: 'my-cli',
  buildArgs: (args) => args,
  installHooks: () => ({ changed: false, trustNotice: null }),
  stateForHookEvent: () => null,
  resolveAction: (action) => {
    if (action.type === 'accept') return { bytes: '\r' }
    if (action.type === 'reject') return { bytes: '\x1b' }
    if (action.type === 'prompt') return { bytes: `${action.text}\r` }
    if (action.type === 'keys') return { bytes: action.bytes }
    return null
  },
}

registerHarness(myHarness)
```

The binary does not load harness plugins from configuration yet, so a third-party registration currently needs a small custom entry point.

## Embed controller input

The `openmicro/controller` API exposes the same controller manager used by the CLI without starting the CLI, installing hooks, creating configuration, opening a PTY, or binding a server.

```ts
import { HidManager } from 'openmicro/controller'
import type { ControllerEvent } from 'openmicro/controller'

const controller = new HidManager()
controller.on('data', (event: ControllerEvent) => {
  // Handle normalized controller input.
})
controller.start()

// Release polling and the active HID device during shutdown.
controller.stop()
```

`start()` discovers and verifies a supported device, emits a `connected` event, then emits deduplicated `button` and `axis` state changes. Stick axes use `-1..1`; triggers use `0..1`. A `disconnected` event is followed by automatic reconnect polling. `start()` and `stop()` are idempotent; call `stop()` when the consumer shuts down to release polling and device ownership.

## Embed GUI status logs

The side-effect-free `openmicro/logging` API exposes the same safe status messages as the OpenMicro GUI CLI:

```ts
import { actionStatus, agentStatus, controllerStatus } from 'openmicro/logging'

const lifecycle = controllerStatus(controllerEvent)
const action = actionStatus('north', 'dualsense', { type: 'push_to_talk', pressed: true })
const state = agentStatus(['waiting'], previousStateKey)
```

Each function returns `{ message, tone }` or `null`; agent statuses also return `stateKey` for the next deduplication call. Prompt text and unknown raw key bytes are never included. The embedding application owns output, ANSI styling, successful-action checks, and repeat/release suppression.

## Troubleshooting

### Controller is connected but OpenMicro cannot open it

Another process probably owns the device exclusively. Quit other controller tools, Steam, browser tabs using Gamepad/WebHID, and PS Remote Play, then retry.

On macOS, this command lists processes with the DualSense open:

```sh
ioreg -r -n "DualSense Wireless Controller" -l -w0 | grep IOUserClientCreator
```

Current macOS versions do not require Input Monitoring permission for game controllers.
