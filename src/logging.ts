import type { Action, AgentState } from './harness/types.js'
import { actionLabel, controlLabel } from './labels.js'
import type { ControlId } from './layers.js'
import type { ControllerEvent, ControllerType } from './types.js'

export type GuiStatusTone = 'success' | 'warning' | 'action' | AgentState
export type GuiStatusKind = 'lifecycle' | 'controller' | 'action' | 'agent'

export interface GuiStatus {
  kind: GuiStatusKind
  message: string
  tone: GuiStatusTone
  state?: string
  controllerType?: ControllerType
  control?: ControlId
  actionType?: Action['type']
}

export interface AgentStatus extends GuiStatus {
  stateKey: string
}

/** Format a controller lifecycle event for a GUI consumer. */
export function controllerStatus(event: ControllerEvent): GuiStatus | null {
  if (event.kind === 'connected') {
    return {
      kind: 'controller',
      message: `controller connected (${event.controllerType}) — buttons now drive the app`,
      tone: 'success',
      state: 'connected',
      controllerType: event.controllerType,
    }
  }
  if (event.kind === 'disconnected') {
    return {
      kind: 'controller',
      message: 'controller disconnected — waiting…',
      tone: 'warning',
      state: 'disconnected',
    }
  }
  return null
}

/** Format a successfully routed controller action without exposing its payload. */
export function actionStatus(
  control: ControlId | null,
  controllerType: ControllerType,
  action: Action,
): GuiStatus | null {
  if (!control) return null
  return {
    kind: 'action',
    message: `${controlLabel(control, controllerType)} → ${actionLabel(action)}`,
    tone: 'action',
    control,
    actionType: action.type,
  }
}

/** Format a changed GUI agent-state snapshot. */
export function agentStatus(
  states: readonly AgentState[],
  previousStateKey = '',
): AgentStatus | null {
  const stateKey = states.join(', ')
  if (!stateKey || stateKey === previousStateKey) return null
  return {
    kind: 'agent',
    message: `agent: ${stateKey}`,
    tone: states[0] ?? 'idle',
    state: stateKey,
    stateKey,
  }
}

/** One-line protocol consumed by the native desktop app. */
export function serializeGuiStatus(
  status: GuiStatus,
  timestamp = new Date().toISOString(),
): string {
  return JSON.stringify({ source: 'openmicro', timestamp, ...status })
}
