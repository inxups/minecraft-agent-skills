#!/usr/bin/env bash
set -euo pipefail

ROOT='.'
STRICT=0
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
YAML_MODULE="$SCRIPT_DIR/vendor/js-yaml.min.cjs"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "[FAIL] --root requires a path" >&2
        exit 2
      fi
      ROOT="${2:-}"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: validate-workflow-snippets.sh [--root <path>] [--strict]

Validates workflow snippets inside SKILL.md:
- extracts fenced yaml/yml code blocks
- validates every YAML snippet and checks required workflow keys (name/on/jobs)
- requires action references to use full commit SHAs and container actions to use digests
- detects unresolved placeholders and obviously broken globs
- checks secret usage vs documented secret list in SKILL.md
USAGE
      exit 0
      ;;
    *)
      echo "[FAIL] unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

SKILL_FILE="$ROOT/SKILL.md"
if [[ ! -f "$SKILL_FILE" ]]; then
  echo "[FAIL] missing SKILL.md at $SKILL_FILE"
  exit 1
fi

node - "$SKILL_FILE" "$STRICT" "$YAML_MODULE" <<'NODE'
const fs = require('node:fs');

const skillFile = process.argv[2];
const strict = process.argv[3] === '1';
const yamlModule = process.argv[4];

let yaml;
try {
  yaml = require(yamlModule);
} catch (error) {
  console.error(`[FAIL] missing bundled YAML parser at ${yamlModule}: ${String(error.message || error)}`);
  process.exit(1);
}

const text = fs.readFileSync(skillFile, 'utf8').replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');

let failures = 0;
let warnings = 0;

const pass = (msg) => console.log(`[PASS] ${msg}`);
const warn = (msg) => {
  warnings += 1;
  console.log(`[WARN] ${msg}`);
};
const fail = (msg) => {
  failures += 1;
  console.log(`[FAIL] ${msg}`);
};

console.log('=== Workflow Snippet Validator ===');

const blocks = [];
const fenceRe = /(```|~~~)(?:yaml|yml)(?:[ \t][^\n]*)?\n([\s\S]*?)\1/g;
let match;
while ((match = fenceRe.exec(text)) !== null) {
  blocks.push(match[2]);
}

if (blocks.length === 0) {
  fail('no yaml/yml fenced code blocks found in SKILL.md');
}

const usedSecrets = new Set();
const documentedSecrets = new Set();

const secretUseRe = /\$\{\{\s*secrets\.([A-Z0-9_]+)\s*\}\}/g;
let sm;
while ((sm = secretUseRe.exec(text)) !== null) {
  usedSecrets.add(sm[1]);
}

const lines = text.split(/\r?\n/);
let inSecretSection = false;
for (const line of lines) {
  if (/^##+\s+.*secret/i.test(line)) {
    inSecretSection = true;
    continue;
  }
  if (inSecretSection && /^##+\s+/.test(line)) {
    inSecretSection = false;
  }
  if (!inSecretSection) continue;

  for (const m of line.matchAll(/`([A-Z][A-Z0-9_]{2,})`/g)) {
    documentedSecrets.add(m[1]);
  }
  for (const m of line.matchAll(/\b([A-Z][A-Z0-9_]*(?:TOKEN|SECRET|KEY))\b/g)) {
    documentedSecrets.add(m[1]);
  }
}

if (usedSecrets.size === 0) {
  warn('no `${{ secrets.* }}` references found');
} else {
  pass(`found ${usedSecrets.size} secret reference(s)`);
}

for (const secret of usedSecrets) {
  if (!documentedSecrets.has(secret)) {
    fail(`secret used but not documented in a Secrets section: ${secret}`);
  }
}
for (const secret of documentedSecrets) {
  if (!usedSecrets.has(secret)) {
    warn(`secret documented but not referenced in snippets: ${secret}`);
  }
}

const placeholderRe = /(REPLACE_ME|TODO|<[^>]+>|yourname|your-repo|path\/to\/|example\/repo)/i;
const badGlobRe = /\*\*\*|\*\*\/\*\*\/|\.\*\*/;
const mappingLineRe = /^(?:"[^"]+"|'[^']+'|[^:#][^:]*?):(?:\s+.*)?$/;

function validateActionRef(label, lineNumber, ref) {
  if (ref.startsWith('./')) return;

  if (ref.startsWith('docker://')) {
    if (!/^docker:\/\/[^@\s]+@sha256:[0-9a-f]{64}$/.test(ref)) {
      fail(`${label} line ${lineNumber} container action must be pinned to a sha256 digest: ${ref}`);
    }
    return;
  }

  if (!ref.includes('@')) {
    fail(`${label} line ${lineNumber} action reference is missing a ref: ${ref}`);
    return;
  }

  if (!/@[0-9a-f]{40}$/.test(ref)) {
    fail(`${label} line ${lineNumber} action must be pinned to a full commit SHA: ${ref}`);
  }
}

function inspectBlock(block) {
  const topLevelKeys = new Set();
  const lines = block.split(/\r?\n/);
  const significantIndents = [];

  for (const line of lines) {
    if (!line.trim()) continue;

    const indent = line.match(/^ */)[0].length;
    const trimmed = line.slice(indent);
    if (!trimmed || trimmed.startsWith('#')) continue;
    significantIndents.push(indent);
  }

  const baseIndent = significantIndents.length > 0 ? Math.min(...significantIndents) : 0;

  for (let idx = 0; idx < lines.length; idx += 1) {
    const line = lines[idx];
    if (!line.trim()) continue;

    const indent = line.match(/^ */)[0].length;
    const trimmed = line.slice(indent);

    if (!trimmed || trimmed.startsWith('#')) continue;

    if (indent === baseIndent && mappingLineRe.test(trimmed)) {
      topLevelKeys.add(trimmed.split(':', 1)[0].trim().replace(/^['"]|['"]$/g, ''));
    }
  }

  return { topLevelKeys };
}

blocks.forEach((block, idx) => {
  const label = `block #${idx + 1}`;
  const { topLevelKeys } = inspectBlock(block);
  const isWorkflowLike = topLevelKeys.has('jobs') || topLevelKeys.has('on');
  let parsed;

  try {
    parsed = yaml.load(block);
  } catch (error) {
    const message = String(error.message || error).split('\n')[0];
    fail(`${label} is not valid YAML: ${message}`);
    return;
  }

  if (isWorkflowLike) {
    if (!parsed || typeof parsed !== 'object' || Array.isArray(parsed)) {
      fail(`${label} is not valid YAML: top-level workflow document must be a mapping`);
      return;
    }

    const parsedTopLevelKeys = new Set(Object.keys(parsed));
    if (!parsedTopLevelKeys.has('name')) fail(`${label} missing top-level \`name:\``);
    if (!parsedTopLevelKeys.has('on')) fail(`${label} missing top-level \`on:\``);
    if (!parsedTopLevelKeys.has('jobs')) fail(`${label} missing top-level \`jobs:\``);
  }

  if (placeholderRe.test(block)) {
    fail(`${label} contains unresolved placeholder text`);
  } else {
    pass(`${label} has no obvious placeholder tokens`);
  }

  if (badGlobRe.test(block)) {
    warn(`${label} contains suspicious glob pattern`);
  }

  const blockLines = block.split(/\r?\n/);
  blockLines.forEach((line, lineIdx) => {
    const usesMatch = line.match(/^\s*(?:-\s*)?uses:\s*['"]?([^'"#\s]+)['"]?(?:\s+#.*)?$/);
    if (usesMatch) validateActionRef(label, lineIdx + 1, usesMatch[1]);

    if (/\t/.test(line)) {
      fail(`${label} line ${lineIdx + 1} contains tab indentation`);
    }
    if (/^ +/.test(line)) {
      const spaces = line.match(/^ +/)[0].length;
      if (spaces % 2 !== 0) {
        warn(`${label} line ${lineIdx + 1} uses odd indentation (${spaces} spaces)`);
      }
    }
  });
});

if (failures > 0) {
  console.log(`[FAIL] workflow snippet validation failed with ${failures} error(s) and ${warnings} warning(s)`);
  process.exit(1);
}

if (strict && warnings > 0) {
  console.log(`[FAIL] workflow snippet strict mode failed on ${warnings} warning(s)`);
  process.exit(1);
}

console.log(`[PASS] workflow snippet validation passed with ${warnings} warning(s)`);
NODE
