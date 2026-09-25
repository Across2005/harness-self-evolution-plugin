const DSH_VERSION_TOKEN = /(?<![\w.-])v?(\d+\.\d+\.\d+(?:-[0-9A-Za-z]+(?:[.-][0-9A-Za-z]+)*)?)(?![\w.-])/u

/** Extract one bounded semantic-version token from decorated CLI output. */
export function extractDshVersion(output) {
  const match = String(output).trim().match(DSH_VERSION_TOKEN)
  return match?.[1] ?? null
}

/** Compare the CLI's version token exactly, never by substring. */
export function isExactDshVersion(output, expected) {
  return extractDshVersion(output) === expected
}
