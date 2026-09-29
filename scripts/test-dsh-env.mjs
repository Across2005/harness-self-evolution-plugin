import assert from 'node:assert/strict'
import test from 'node:test'
import { sanitizedNodeEnv } from './dsh-env.mjs'

test('drops legacy host package-manager keys and keeps unrelated environment', () => {
  const env = sanitizedNodeEnv({}, {
    npm_config_side_effects_cache: 'true',
    PNPM_CONFIG_SIDE_EFFECTS_CACHE: 'true',
    KEEP_ME: 'yes',
  })
  assert.equal('npm_config_side_effects_cache' in env, false)
  assert.equal('PNPM_CONFIG_SIDE_EFFECTS_CACHE' in env, false)
  assert.equal(env.KEEP_ME, 'yes')
})

test('defaults npm diagnostics to silent and preserves an explicit override', () => {
  assert.equal(sanitizedNodeEnv({}, {}).NPM_CONFIG_LOGLEVEL, 'silent')
  assert.equal(sanitizedNodeEnv({}, { NPM_CONFIG_LOGLEVEL: 'warn' }).NPM_CONFIG_LOGLEVEL, 'warn')
})

test('applies DSH-specific overrides after sanitization', () => {
  const env = sanitizedNodeEnv({ DSH_HOME: 'C:/tree' }, { DSH_HOME: 'C:/old' })
  assert.equal(env.DSH_HOME, 'C:/tree')
})
