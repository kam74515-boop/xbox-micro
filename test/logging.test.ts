import fs from 'node:fs'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import {
  actionStatus,
  agentStatus,
  controllerStatus,
  serializeGuiStatus,
  type GuiStatus,
} from '../src/logging.js'

describe('public logging statuses', () => {
  it('formats controller lifecycle without owning terminal output', () => {
    expect(controllerStatus({ kind: 'connected', controllerType: 'dualsense' })).toEqual({
      kind: 'controller',
      message: 'controller connected (dualsense) — buttons now drive the app',
      tone: 'success',
      state: 'connected',
      controllerType: 'dualsense',
    } satisfies GuiStatus)
    expect(controllerStatus({ kind: 'disconnected' })).toEqual({
      kind: 'controller',
      message: 'controller disconnected — waiting…',
      tone: 'warning',
      state: 'disconnected',
    } satisfies GuiStatus)
    expect(controllerStatus({ kind: 'button', button: 'south', pressed: true })).toBeNull()
  })

  it('formats a routed action once with controller-specific labels', () => {
    expect(actionStatus('north', 'dualsense', { type: 'push_to_talk', pressed: true })).toEqual({
      kind: 'action',
      message: '△ → push-to-talk',
      tone: 'action',
      control: 'north',
      actionType: 'push_to_talk',
    } satisfies GuiStatus)
    expect(actionStatus('south', 'xbox', { type: 'accept' })).toEqual({
      kind: 'action',
      message: 'A → accept',
      tone: 'action',
      control: 'south',
      actionType: 'accept',
    } satisfies GuiStatus)
    expect(actionStatus(null, 'dualsense', { type: 'accept' })).toBeNull()
  })

  it('never exposes prompt text or unknown raw key bytes', () => {
    const prompt = 'do not print this secret'
    const bytes = '\x00private raw bytes'
    const promptStatus = actionStatus('lstick_up', 'dualsense', { type: 'prompt', text: prompt })
    const keyStatus = actionStatus('dpad_up', 'dualsense', { type: 'keys', bytes })

    expect(promptStatus?.message).toBe('left stick flick up → prompt')
    expect(promptStatus?.message).not.toContain(prompt)
    expect(keyStatus?.message).toBe('d-pad up → send keys')
    expect(keyStatus?.message).not.toContain(bytes)
  })

  it('deduplicates agent-state snapshots', () => {
    expect(agentStatus(['waiting', 'executing'], '')).toEqual({
      kind: 'agent',
      message: 'agent: waiting, executing',
      tone: 'waiting',
      state: 'waiting, executing',
      stateKey: 'waiting, executing',
    })
    expect(agentStatus(['waiting', 'executing'], 'waiting, executing')).toBeNull()
    expect(agentStatus([], '')).toBeNull()
  })

  it('serializes a stable one-line desktop protocol without ANSI escapes', () => {
    const line = serializeGuiStatus(
      {
        kind: 'controller',
        message: 'controller connected',
        tone: 'success',
        state: 'connected',
        controllerType: 'xbox',
      },
      '2026-08-28T00:00:00.000Z',
    )
    expect(JSON.parse(line)).toEqual({
      source: 'openmicro',
      timestamp: '2026-08-28T00:00:00.000Z',
      kind: 'controller',
      message: 'controller connected',
      tone: 'success',
      state: 'connected',
      controllerType: 'xbox',
    })
    expect(line).not.toContain('\x1b')
  })

  it('is the CLI status source', () => {
    const cli = fs.readFileSync(fileURLToPath(new URL('../src/cli.ts', import.meta.url)), 'utf8')
    expect(cli).toContain("from './logging.js'")
    expect(cli).not.toContain("from './labels.js'")
    expect(cli).toContain('reportGuiStatus(actionStatus(')
    expect(cli).toContain('const status = agentStatus(')
    expect(cli).toContain('OPENMICRO_PARENT_PID')
    expect(cli.match(/reportGuiStatus\(controllerStatus\(e\)\)/g)).toHaveLength(2)
  })
})
