#!/usr/bin/env bash
set -euo pipefail

PASS='[PASS]'
FAIL='[FAIL]'

expect_pass() {
  local name="$1"
  shift
  if "$@"; then
    echo "$PASS $name"
  else
    echo "$FAIL $name (expected pass)" >&2
    exit 1
  fi
}

expect_fail() {
  local name="$1"
  shift
  if "$@"; then
    echo "$FAIL $name (expected failure)" >&2
    exit 1
  else
    echo "$PASS $name"
  fi
}

echo "=== Running Skill Validator Fixtures ==="

expect_pass "datapack valid" \
  ./.agents/skills/minecraft-datapack/scripts/validate-datapack.sh \
  --root tests/fixtures/validators/datapack/valid
expect_fail "datapack invalid" \
  ./.agents/skills/minecraft-datapack/scripts/validate-datapack.sh \
  --root tests/fixtures/validators/datapack/invalid

expect_pass "resource-pack valid" \
  ./.agents/skills/minecraft-resource-pack/scripts/validate-resource-pack.sh \
  --root tests/fixtures/validators/resource-pack/valid
expect_fail "resource-pack invalid" \
  ./.agents/skills/minecraft-resource-pack/scripts/validate-resource-pack.sh \
  --root tests/fixtures/validators/resource-pack/invalid

expect_pass "ci-release valid" \
  ./.agents/skills/minecraft-ci-release/scripts/validate-workflow-snippets.sh \
  --root tests/fixtures/validators/ci-release/valid
expect_fail "ci-release invalid" \
  ./.agents/skills/minecraft-ci-release/scripts/validate-workflow-snippets.sh \
  --root tests/fixtures/validators/ci-release/invalid

expect_pass "plugin-dev valid" \
  ./.agents/skills/minecraft-plugin-dev/scripts/validate-plugin-layout.sh \
  --root tests/fixtures/validators/plugin-dev/valid
expect_fail "plugin-dev invalid" \
  ./.agents/skills/minecraft-plugin-dev/scripts/validate-plugin-layout.sh \
  --root tests/fixtures/validators/plugin-dev/invalid

expect_pass "worldgen valid" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/valid
expect_fail "worldgen invalid" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/invalid

echo "$PASS all validator fixture checks completed"
