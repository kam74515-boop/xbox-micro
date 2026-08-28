import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { describe, expect, it } from 'vitest'
import { CONTROL_IDS, DEFAULT_CONFIG } from '../src/layers.js'

const root = fileURLToPath(new URL('..', import.meta.url))
const models = fs.readFileSync(
  path.join(root, 'desktop/Sources/XboxMicroCore/Models.swift'),
  'utf8',
)
const packageManifest = fs.readFileSync(path.join(root, 'desktop/Package.swift'), 'utf8')
const buildScript = fs.readFileSync(path.join(root, 'desktop/scripts/build-app.zsh'), 'utf8')

describe('native desktop contract', () => {
  it('exposes every engine control in the Swift mapping editor', () => {
    expect(CONTROL_IDS).toHaveLength(29)
    for (const id of CONTROL_IDS) expect(models).toContain(`.init("${id}",`)
  })

  it('mirrors every engine action discriminator', () => {
    for (const actionType of [
      'accept',
      'reject',
      'push_to_talk',
      'new_chat',
      'thinking_depth',
      'workflow',
      'prompt',
      'focus_session',
      'layer',
      'herdr_space',
      'keys',
    ]) {
      expect(models).toContain(actionType)
    }
  })

  it('ships six populated, navigable default experience layers', () => {
    expect(DEFAULT_CONFIG.layers).toHaveLength(6)
    DEFAULT_CONFIG.layers.forEach((layer, index) => {
      expect(Object.keys(layer.bindings).length).toBeGreaterThanOrEqual(6)
      expect(layer.bindings.menu).toEqual({ type: 'layer', index: (index + 1) % 6 })
      expect(layer.bindings.view).toEqual({ type: 'layer', index: (index + 5) % 6 })
    })
  })

  it('has a native executable target and self-contained app/dmg packaging', () => {
    expect(packageManifest).toContain('.executable(name: "XboxMicro"')
    expect(buildScript).toContain('Contents/Resources/Runtime/node')
    expect(buildScript).toContain('npm-cli.js" ci --omit=dev')
    expect(buildScript).toContain('codesign --verify --deep --strict')
    expect(buildScript).toContain('hdiutil create')
  })
})
