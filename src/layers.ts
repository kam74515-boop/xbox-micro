// User config: 6 remappable layers + workflow prompt presets, persisted at
// ~/.openmicro/config.json (zod-validated, atomic tmp+rename like
// hooks-install.ts). Layer 0 ships the Codex Micro parity bindings from
// PLAN.md; layers 1-5 are blank canvases the user fills in via the config
// file. A missing file self-seeds with DEFAULT_CONFIG; an invalid file is
// never touched — loadConfig throws instead, so a typo can't be silently
// clobbered.

import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { z } from 'zod'
import type { RGB } from './feedback.js'
import type { Action } from './harness/types.js'
import type { ButtonId } from './types.js'

export type StickControlId =
  | 'lstick_up'
  | 'lstick_down'
  | 'lstick_left'
  | 'lstick_right'
  | 'lstick_cw'
  | 'lstick_ccw'
  | 'rstick_up'
  | 'rstick_down'
  | 'rstick_left'
  | 'rstick_right'
  | 'rstick_cw'
  | 'rstick_ccw'

export type ControlId = ButtonId | StickControlId

export interface Layer {
  name: string
  color: RGB
  bindings: Partial<Record<ControlId, Action>>
}

export interface OpenMicroConfig {
  /** Exactly 6 layers, index = layer number (0-5). */
  layers: [Layer, Layer, Layer, Layer, Layer, Layer]
  /** presetId -> prompt template text, referenced by `{ type: 'workflow', presetId }` bindings. */
  workflows: Record<string, string>
}

export const CONTROL_IDS: readonly ControlId[] = [
  'south',
  'east',
  'west',
  'north',
  'dpad_up',
  'dpad_down',
  'dpad_left',
  'dpad_right',
  'l1',
  'r1',
  'l2',
  'r2',
  'l3',
  'r3',
  'menu',
  'view',
  'touchpad',
  'lstick_up',
  'lstick_down',
  'lstick_left',
  'lstick_right',
  'lstick_cw',
  'lstick_ccw',
  'rstick_up',
  'rstick_down',
  'rstick_left',
  'rstick_right',
  'rstick_cw',
  'rstick_ccw',
]
const CONTROL_ID_SET: ReadonlySet<string> = new Set(CONTROL_IDS)

const rgbSchema = z.object({ r: z.number(), g: z.number(), b: z.number() })

// Mirrors src/harness/types.ts `Action` exactly. Kept in sync by hand — the
// harness contract is the source of truth and rarely changes.
const actionSchema = z.discriminatedUnion('type', [
  z.object({ type: z.literal('accept') }),
  z.object({ type: z.literal('reject') }),
  z.object({ type: z.literal('push_to_talk') }),
  z.object({ type: z.literal('new_chat') }),
  z.object({ type: z.literal('thinking_depth'), delta: z.union([z.literal(1), z.literal(-1)]) }),
  z.object({ type: z.literal('workflow'), presetId: z.string() }),
  z.object({ type: z.literal('prompt'), text: z.string() }),
  z.object({ type: z.literal('focus_session'), index: z.number() }),
  z.object({ type: z.literal('layer'), index: z.number() }),
  z.object({ type: z.literal('herdr_space') }),
  z.object({ type: z.literal('keys'), bytes: z.string() }),
])

// z.record with an enum key schema requires every enum key present (not what
// we want for a Partial<Record<...>>), so validate keys loosely + a refine.
const bindingsSchema = z
  .record(z.string(), actionSchema)
  .refine((bindings) => Object.keys(bindings).every((key) => CONTROL_ID_SET.has(key)), {
    message: `binding keys must be one of: ${CONTROL_IDS.join(', ')}`,
  })

const layerSchema = z.object({
  name: z.string(),
  color: rgbSchema,
  bindings: bindingsSchema,
})

const configSchema = z.object({
  layers: z.array(layerSchema).length(6),
  workflows: z.record(z.string(), z.string()),
})

// touchpad cycles focus across occupied session slots. `focus_session` is a
// core-handled action (never reaches a Harness); index -1 is a sentinel this
// binding uses to mean "cycle to the next session" rather than "jump to slot N".
const TOUCHPAD_CYCLE: Action = { type: 'focus_session', index: -1 }

const LAYER_COLORS: RGB[] = [
  { r: 255, g: 255, b: 255 }, // Layer 1 (default) — white
  { r: 160, g: 32, b: 240 }, // Layer 2 — purple
  { r: 0, g: 255, b: 255 }, // Layer 3 — cyan
  { r: 255, g: 140, b: 0 }, // Layer 4 — orange
  { r: 255, g: 20, b: 147 }, // Layer 5 — pink
  { r: 255, g: 255, b: 0 }, // Layer 6 — yellow
]

const FACE_BINDINGS: Layer['bindings'] = {
  south: { type: 'accept' },
  east: { type: 'reject' },
  north: { type: 'push_to_talk' },
  west: { type: 'new_chat' },
}

const DPAD_BINDINGS: Layer['bindings'] = {
  dpad_up: { type: 'keys', bytes: '\x1b[A' },
  dpad_down: { type: 'keys', bytes: '\x1b[B' },
  dpad_right: { type: 'keys', bytes: '\x1b[C' },
  dpad_left: { type: 'keys', bytes: '\x1b[D' },
}

function configuredLayer(index: number, name: string, bindings: Layer['bindings']): Layer {
  return {
    name,
    color: LAYER_COLORS[index]!,
    bindings: {
      menu: { type: 'layer', index: (index + 1) % 6 },
      view: { type: 'layer', index: (index + 5) % 6 },
      ...bindings,
    },
  }
}

export const DEFAULT_CONFIG: OpenMicroConfig = {
  layers: [
    configuredLayer(0, 'Codex 主控', {
      ...FACE_BINDINGS,
      ...DPAD_BINDINGS,
      r1: { type: 'keys', bytes: '\x1b[Z' }, // Shift+Tab — cycle permission/plan modes
      r2: { type: 'keys', bytes: '\x15' }, // Ctrl+U — clear the input line
      lstick_up: { type: 'workflow', presetId: 'review-pr' },
      lstick_down: { type: 'workflow', presetId: 'debug' },
      lstick_left: { type: 'workflow', presetId: 'refactor' },
      lstick_right: { type: 'workflow', presetId: 'write-tests' },
      l2: { type: 'herdr_space' },
      // Flicks, not cw/ccw rotation — rotation gestures proved finicky to
      // perform reliably; left/right flicks are still remappable to cw/ccw.
      rstick_right: { type: 'thinking_depth', delta: 1 },
      rstick_left: { type: 'thinking_depth', delta: -1 },
      // Ctrl+Shift+M (CSI-u encoding). In the Codex app this opens the model
      // picker (user-assigned ^⇧M) so the thinking dial has a visual.
      r3: { type: 'keys', bytes: '\x1b[109;6u' },
      touchpad: TOUCHPAD_CYCLE,
    }),
    configuredLayer(1, '语音与提示', {
      ...FACE_BINDINGS,
      ...DPAD_BINDINGS,
      l1: { type: 'workflow', presetId: 'review-pr' },
      r1: { type: 'workflow', presetId: 'debug' },
      l2: { type: 'workflow', presetId: 'refactor' },
      r2: { type: 'workflow', presetId: 'write-tests' },
      l3: { type: 'prompt', text: '总结当前任务的进展、风险和下一步。' },
      r3: { type: 'prompt', text: '解释当前屏幕中的结果，并告诉我应该选择什么。' },
      touchpad: TOUCHPAD_CYCLE,
    }),
    configuredLayer(2, '代码审查', {
      ...FACE_BINDINGS,
      ...DPAD_BINDINGS,
      west: { type: 'workflow', presetId: 'review-pr' },
      l1: { type: 'prompt', text: '仅检查当前改动中的安全漏洞、权限边界和敏感数据风险。' },
      r1: { type: 'prompt', text: '审查未提交改动，按严重程度列出问题并引用文件与行号。' },
      l2: { type: 'prompt', text: '列出当前改动最可能导致回归的三个风险。' },
      r2: { type: 'prompt', text: '基于审查结果生成最小修复计划，暂时不要修改代码。' },
      lstick_left: { type: 'workflow', presetId: 'refactor' },
      lstick_right: { type: 'workflow', presetId: 'write-tests' },
      touchpad: TOUCHPAD_CYCLE,
    }),
    configuredLayer(3, '调试与测试', {
      ...FACE_BINDINGS,
      ...DPAD_BINDINGS,
      west: { type: 'workflow', presetId: 'debug' },
      l1: { type: 'workflow', presetId: 'debug' },
      r1: { type: 'workflow', presetId: 'write-tests' },
      l2: { type: 'workflow', presetId: 'refactor' },
      r2: { type: 'workflow', presetId: 'review-pr' },
      lstick_up: { type: 'prompt', text: '运行最相关的测试并解释第一个失败的根因。' },
      lstick_down: { type: 'prompt', text: '检查日志和错误堆栈，提取最早的有效失败信号。' },
      touchpad: TOUCHPAD_CYCLE,
    }),
    configuredLayer(4, '任务导航', {
      ...FACE_BINDINGS,
      ...DPAD_BINDINGS,
      l1: { type: 'keys', bytes: '\x1b[Z' },
      r1: { type: 'keys', bytes: '\t' },
      l2: { type: 'herdr_space' },
      r2: { type: 'keys', bytes: '\x15' },
      rstick_right: { type: 'thinking_depth', delta: 1 },
      rstick_left: { type: 'thinking_depth', delta: -1 },
      touchpad: TOUCHPAD_CYCLE,
    }),
    configuredLayer(5, '自定义', {
      ...FACE_BINDINGS,
    }),
  ],
  workflows: {
    'review-pr':
      '审查当前 PR 的正确性、安全性和代码风格问题。请引用文件路径和行号，并明确指出任何不确定之处。',
    debug:
      '帮我调试当前问题。先询问具体的故障现象以及我已经尝试过的方法，然后调查根因，再提出修复方案。',
    refactor:
      '在不改变现有行为的前提下重构当前代码，使其更清晰、更简洁。说明每项改动，并保持最小必要差异。',
    'write-tests': '为当前代码编写测试，覆盖正常路径以及最可能在生产环境中出错的边界情况。',
  },
}

function defaultConfigPath(): string {
  return path.join(os.homedir(), '.openmicro', 'config.json')
}

/**
 * Atomically write a config to disk (tmp file + rename, same pattern as hooks-install.ts).
 *
 * Args:
 *     config (OpenMicroConfig): Config to persist.
 *     configPath (string): Target path. Defaults to ~/.openmicro/config.json.
 *
 * Returns:
 *     None.
 */
export function saveConfig(
  config: OpenMicroConfig,
  configPath: string = defaultConfigPath(),
): void {
  fs.mkdirSync(path.dirname(configPath), { recursive: true })
  const tmp = `${configPath}.tmp-${process.pid}`
  fs.writeFileSync(tmp, JSON.stringify(config, null, 2) + '\n', 'utf8')
  fs.renameSync(tmp, configPath)
}

/**
 * Load the config, seeding a fresh DEFAULT_CONFIG file when none exists.
 *
 * Args:
 *     configPath (string): Target path. Defaults to ~/.openmicro/config.json.
 *
 * Returns:
 *     OpenMicroConfig: The loaded (or freshly-seeded default) config.
 *
 * Throws:
 *     Error: The file exists but is not valid JSON or fails schema validation. The file is left untouched.
 */
export function loadConfig(configPath: string = defaultConfigPath()): OpenMicroConfig {
  let raw: string
  try {
    raw = fs.readFileSync(configPath, 'utf8')
  } catch (err) {
    if ((err as NodeJS.ErrnoException).code === 'ENOENT') {
      saveConfig(DEFAULT_CONFIG, configPath)
      return DEFAULT_CONFIG
    }
    throw err
  }

  let parsed: unknown
  try {
    parsed = JSON.parse(raw)
  } catch (err) {
    throw new Error(
      `openmicro: config at ${configPath} is not valid JSON: ${(err as Error).message}`,
    )
  }

  const result = configSchema.safeParse(parsed)
  if (!result.success) {
    const issues = result.error.issues.map((i) => `${i.path.join('.') || '(root)'}: ${i.message}`)
    throw new Error(`openmicro: invalid config at ${configPath}:\n${issues.join('\n')}`)
  }
  return result.data as OpenMicroConfig
}
