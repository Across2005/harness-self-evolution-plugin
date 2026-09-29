const LEGACY_PACKAGE_ENV_KEYS = [
  'npm_config_side_effects_cache',
  'pnpm_config_side_effects_cache',
]

/**
 * Build the environment shared by workspace build tools and DSH smoke tests.
 * Host-level legacy package-manager keys are removed; DSH's bundled bootstrap
 * stays quiet unless the caller explicitly chooses a different npm log level.
 */
export function sanitizedNodeEnv(overrides = {}, base = process.env) {
  const env = {
    ...base,
    NPM_CONFIG_LOGLEVEL: base.NPM_CONFIG_LOGLEVEL ?? 'silent',
  }
  const legacyKeys = new Set(LEGACY_PACKAGE_ENV_KEYS.map((key) => key.toLowerCase()))
  for (const key of Object.keys(env)) {
    if (legacyKeys.has(key.toLowerCase())) delete env[key]
  }
  return { ...env, ...overrides }
}
