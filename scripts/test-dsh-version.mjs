import assert from 'node:assert/strict'
import test from 'node:test'
import { extractDshVersion, isExactDshVersion } from './dsh-version.mjs'

test('accepts an exact version in bare or decorated CLI output', () => {
  assert.equal(extractDshVersion('0.1.5-rc.2'), '0.1.5-rc.2')
  assert.equal(extractDshVersion('DSH v0.1.6-alpha.1 (build 42)'), '0.1.6-alpha.1')
  assert.equal(isExactDshVersion('DSH 0.1.5-rc.2', '0.1.5-rc.2'), true)
})

test('rejects a longer prerelease that only contains the expected text', () => {
  assert.equal(isExactDshVersion('0.1.5-rc.20', '0.1.5-rc.2'), false)
  assert.equal(isExactDshVersion('0.1.6-alpha.10', '0.1.6-alpha.1'), false)
})

test('rejects malformed or missing version output', () => {
  assert.equal(isExactDshVersion('DSH build unknown', '0.1.5-rc.2'), false)
  assert.equal(isExactDshVersion('version 0.1.5-rc.2.1', '0.1.5-rc.2'), false)
})
