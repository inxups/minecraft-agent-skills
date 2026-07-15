#!/usr/bin/env bash
set -euo pipefail

PASS='[PASS]'
FAIL='[FAIL]'

expect_path() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    echo "$FAIL missing fixture path: $path" >&2
    exit 1
  fi
}

run_and_capture() {
  local output_file
  output_file="$(mktemp)"
  if "$@" >"$output_file" 2>&1; then
    cat "$output_file"
    rm -f "$output_file"
    return 0
  else
    local status=$?
    cat "$output_file"
    rm -f "$output_file"
    return "$status"
  fi
}

expect_pass() {
  local name="$1"
  shift
  if run_and_capture "$@"; then
    echo "$PASS $name"
  else
    echo "$FAIL $name (expected pass)" >&2
    exit 1
  fi
}

expect_pass_contains() {
  local name="$1"
  local pattern="$2"
  shift
  shift

  local output_file
  output_file="$(mktemp)"
  if "$@" >"$output_file" 2>&1; then
    if grep -Fq "$pattern" "$output_file"; then
      cat "$output_file"
      rm -f "$output_file"
      echo "$PASS $name"
    else
      cat "$output_file"
      rm -f "$output_file"
      echo "$FAIL $name (missing expected output: $pattern)" >&2
      exit 1
    fi
  else
    cat "$output_file"
    rm -f "$output_file"
    echo "$FAIL $name (expected pass)" >&2
    exit 1
  fi
}

expect_fail_contains() {
  local name="$1"
  local pattern="$2"
  shift
  shift

  local output_file
  output_file="$(mktemp)"
  if "$@" >"$output_file" 2>&1; then
    cat "$output_file"
    rm -f "$output_file"
    echo "$FAIL $name (expected failure)" >&2
    exit 1
  elif grep -Fq "$pattern" "$output_file"; then
    cat "$output_file"
    rm -f "$output_file"
    echo "$PASS $name"
  else
    cat "$output_file"
    rm -f "$output_file"
    echo "$FAIL $name (missing expected output: $pattern)" >&2
    exit 1
  fi
}

expect_temp_skill_pass() {
  local name="$1"
  local skill_dir="$2"
  local temp_dir

  temp_dir="$(mktemp -d)"
  cp -R "$skill_dir"/. "$temp_dir"

  if (cd "$temp_dir" && ./scripts/validate-workflow-snippets.sh --root .); then
    rm -rf "$temp_dir"
    echo "$PASS $name"
  else
    local status=$?
    rm -rf "$temp_dir"
    echo "$FAIL $name (expected pass)" >&2
    exit "$status"
  fi
}

echo "=== Running Skill Validator Fixtures ==="

expect_path "tests/fixtures/validators/ci-release/valid/SKILL.md"
expect_path "tests/fixtures/validators/ci-release/invalid/SKILL.md"
expect_path "tests/fixtures/validators/ci-release/invalid-yaml/SKILL.md"
expect_path "tests/fixtures/validators/ci-release/indented-workflow/SKILL.md"
expect_path "tests/fixtures/validators/ci-release/multiline-flow/SKILL.md"
expect_path "tests/fixtures/validators/ci-release/non-workflow-yaml/SKILL.md"
expect_path "tests/fixtures/validators/ci-release/warn-only/SKILL.md"
expect_pass "ci-release valid" \
  ./.agents/skills/minecraft-ci-release/scripts/validate-workflow-snippets.sh \
  --root tests/fixtures/validators/ci-release/valid
expect_pass "ci-release multiline flow yaml" \
  ./.agents/skills/minecraft-ci-release/scripts/validate-workflow-snippets.sh \
  --root tests/fixtures/validators/ci-release/multiline-flow
expect_fail_contains "ci-release invalid" 'missing top-level `jobs:`' \
  ./.agents/skills/minecraft-ci-release/scripts/validate-workflow-snippets.sh \
  --root tests/fixtures/validators/ci-release/invalid
expect_fail_contains "ci-release unpinned action" 'action must be pinned to a full commit SHA' \
  ./.agents/skills/minecraft-ci-release/scripts/validate-workflow-snippets.sh \
  --root tests/fixtures/validators/ci-release/invalid
expect_fail_contains "ci-release invalid yaml" "is not valid YAML" \
  ./.agents/skills/minecraft-ci-release/scripts/validate-workflow-snippets.sh \
  --root tests/fixtures/validators/ci-release/invalid-yaml
expect_fail_contains "ci-release indented workflow" 'missing top-level `jobs:`' \
  ./.agents/skills/minecraft-ci-release/scripts/validate-workflow-snippets.sh \
  --root tests/fixtures/validators/ci-release/indented-workflow
expect_pass "ci-release non-workflow yaml" \
  ./.agents/skills/minecraft-ci-release/scripts/validate-workflow-snippets.sh \
  --root tests/fixtures/validators/ci-release/non-workflow-yaml
expect_fail_contains "ci-release strict warnings" "strict mode failed" \
  ./.agents/skills/minecraft-ci-release/scripts/validate-workflow-snippets.sh \
  --root tests/fixtures/validators/ci-release/warn-only \
  --strict
expect_temp_skill_pass "ci-release standalone installed mirror" \
  ./.codex/skills/minecraft-ci-release

expect_fail_contains "imagegen scaffold missing --type value" "--type requires a value" \
  bash ./.agents/skills/minecraft-imagegen/scripts/scaffold-asset-brief.sh \
  --type

imagegen_workspace="$(mktemp -d)"
imagegen_install_root="$(mktemp -d)"
imagegen_skill_dir="$imagegen_install_root/local/skills/minecraft-imagegen"
mkdir -p "$imagegen_skill_dir"
cp -R ./.agents/skills/minecraft-imagegen/. "$imagegen_skill_dir"
if (
  cd "$imagegen_skill_dir"
  CODEX_WORKSPACE_ROOT="$imagegen_workspace" bash ./scripts/scaffold-asset-brief.sh --type pack-icon --name smoke-test
); then
  if [[ -f "$imagegen_workspace/smoke-test-asset-brief.md" ]]; then
    echo "$PASS imagegen scaffold explicit workspace"
  else
    echo "$FAIL imagegen scaffold explicit workspace (brief missing from configured workspace)" >&2
    rm -rf "$imagegen_workspace" "$imagegen_install_root"
    exit 1
  fi
else
  rm -rf "$imagegen_workspace" "$imagegen_install_root"
  echo "$FAIL imagegen scaffold explicit workspace (expected pass)" >&2
  exit 1
fi
rm -rf "$imagegen_workspace" "$imagegen_install_root"

imagegen_workspace="$(mktemp -d)"
imagegen_install_root="$(mktemp -d)"
imagegen_skill_dir="$imagegen_install_root/local/skills/minecraft-imagegen"
mkdir -p "$imagegen_skill_dir"
cp -R ./.agents/skills/minecraft-imagegen/. "$imagegen_skill_dir"
if (
  cd "$imagegen_skill_dir"
  CODEX_WORKSPACE_ROOT="$imagegen_workspace" bash ./scripts/scaffold-asset-brief.sh --type release-banner --name relative-out --out docs/briefs
); then
  if [[ -f "$imagegen_workspace/docs/briefs/relative-out-asset-brief.md" ]]; then
    if [[ -f "$imagegen_skill_dir/docs/briefs/relative-out-asset-brief.md" ]]; then
      echo "$FAIL imagegen scaffold relative --out resolution (brief was written into installed skill dir)" >&2
      rm -rf "$imagegen_workspace" "$imagegen_install_root"
      exit 1
    fi
    echo "$PASS imagegen scaffold relative --out resolution"
  else
    echo "$FAIL imagegen scaffold relative --out resolution (brief missing from workspace-relative output dir)" >&2
    rm -rf "$imagegen_workspace" "$imagegen_install_root"
    exit 1
  fi
else
  rm -rf "$imagegen_workspace" "$imagegen_install_root"
  echo "$FAIL imagegen scaffold relative --out resolution (expected pass)" >&2
  exit 1
fi
rm -rf "$imagegen_workspace" "$imagegen_install_root"

imagegen_home="$(mktemp -d)"
imagegen_skill_dir="$imagegen_home/.codex/skills/minecraft-imagegen"
mkdir -p "$imagegen_skill_dir"
cp -R ./.agents/skills/minecraft-imagegen/. "$imagegen_skill_dir"
imagegen_output="$(mktemp)"
if (
  cd "$imagegen_skill_dir"
  unset OLDPWD CODEX_WORKSPACE_ROOT
  HOME="$imagegen_home" bash ./scripts/scaffold-asset-brief.sh --type pack-icon --name raw-install
) >"$imagegen_output" 2>&1; then
  cat "$imagegen_output"
  rm -f "$imagegen_output"
  rm -rf "$imagegen_home"
  echo "$FAIL imagegen scaffold raw ~/.codex install requires explicit workspace (expected failure)" >&2
  exit 1
elif grep -Fq "Could not infer a project workspace for the asset brief." "$imagegen_output"; then
  cat "$imagegen_output"
  rm -f "$imagegen_output"
  rm -rf "$imagegen_home"
  echo "$PASS imagegen scaffold raw ~/.codex install requires explicit workspace"
else
  cat "$imagegen_output"
  rm -f "$imagegen_output"
  rm -rf "$imagegen_home"
  echo "$FAIL imagegen scaffold raw ~/.codex install requires explicit workspace (missing expected output)" >&2
  exit 1
fi

imagegen_home="$(mktemp -d)"
imagegen_skill_dir="$imagegen_home/.claude/skills/minecraft-imagegen"
mkdir -p "$imagegen_skill_dir"
cp -R ./.agents/skills/minecraft-imagegen/. "$imagegen_skill_dir"
imagegen_output="$(mktemp)"
if (
  cd "$imagegen_skill_dir"
  unset OLDPWD CODEX_WORKSPACE_ROOT
  HOME="$imagegen_home" bash ./scripts/scaffold-asset-brief.sh --type pack-icon --name raw-install
) >"$imagegen_output" 2>&1; then
  cat "$imagegen_output"
  rm -f "$imagegen_output"
  rm -rf "$imagegen_home"
  echo "$FAIL imagegen scaffold raw ~/.claude install requires explicit workspace (expected failure)" >&2
  exit 1
elif grep -Fq "Could not infer a project workspace for the asset brief." "$imagegen_output"; then
  cat "$imagegen_output"
  rm -f "$imagegen_output"
  rm -rf "$imagegen_home"
  echo "$PASS imagegen scaffold raw ~/.claude install requires explicit workspace"
else
  cat "$imagegen_output"
  rm -f "$imagegen_output"
  rm -rf "$imagegen_home"
  echo "$FAIL imagegen scaffold raw ~/.claude install requires explicit workspace (missing expected output)" >&2
  exit 1
fi

expect_path "tests/fixtures/validators/testing/neoforge-valid"
expect_path "tests/fixtures/validators/testing/neoforge-missing-template"
expect_path "tests/fixtures/validators/testing/neoforge-missing-registration"
expect_path "tests/fixtures/validators/testing/neoforge-nonliteral-template"
expect_path "tests/fixtures/validators/testing/kotlin-valid"
expect_path "tests/fixtures/validators/testing/missing-source-root"
expect_pass "testing neoforge valid" \
  ./.agents/skills/minecraft-testing/scripts/validate-test-layout.sh \
  --root tests/fixtures/validators/testing/neoforge-valid
expect_fail_contains "testing neoforge missing template" "GameTest template fixture missing: mymod:missing_template" \
  ./.agents/skills/minecraft-testing/scripts/validate-test-layout.sh \
  --root tests/fixtures/validators/testing/neoforge-missing-template
expect_fail_contains "testing neoforge missing registration" "NeoForge GameTest class is not registered on an event bus" \
  ./.agents/skills/minecraft-testing/scripts/validate-test-layout.sh \
  --root tests/fixtures/validators/testing/neoforge-missing-registration
expect_pass_contains "testing neoforge nonliteral template" "GameTest template is non-literal and cannot be matched statically" \
  ./.agents/skills/minecraft-testing/scripts/validate-test-layout.sh \
  --root tests/fixtures/validators/testing/neoforge-nonliteral-template
expect_pass "testing Kotlin source root" \
  ./.agents/skills/minecraft-testing/scripts/validate-test-layout.sh \
  --root tests/fixtures/validators/testing/kotlin-valid
expect_fail_contains "testing missing source root" "missing src/test/java or src/test/kotlin" \
  ./.agents/skills/minecraft-testing/scripts/validate-test-layout.sh \
  --root tests/fixtures/validators/testing/missing-source-root

expect_path "tests/fixtures/validators/worldgen/valid"
expect_path "tests/fixtures/validators/worldgen/invalid"
expect_path "tests/fixtures/validators/worldgen/dimensions-only"
expect_path "tests/fixtures/validators/worldgen/empty"
expect_path "tests/fixtures/validators/worldgen/external-dimension-refs-with-tags"
expect_path "tests/fixtures/validators/worldgen/external-dimension-settings"
expect_path "tests/fixtures/validators/worldgen/invalid-dimension-json"
expect_path "tests/fixtures/validators/worldgen/invalid-dimension-refs"
expect_path "tests/fixtures/validators/worldgen/invalid-external-local-dimension-refs"
expect_path "tests/fixtures/validators/worldgen/invalid-tag-layout"
expect_path "tests/fixtures/validators/worldgen/legacy"
expect_path "tests/fixtures/validators/worldgen/nested-paths"
expect_path "tests/fixtures/validators/worldgen/invalid-tags"
expect_path "tests/fixtures/validators/worldgen/tags-only"
expect_path "tests/fixtures/validators/worldgen/invalid-jigsaw-refs"
expect_path "tests/fixtures/validators/worldgen/external-feature-refs"
expect_path "tests/fixtures/validators/worldgen/invalid-placed-json"
expect_pass "worldgen valid" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/valid
expect_pass "worldgen jq fallback" \
  env WORLDGEN_FORCE_JQ_SHIM=1 \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/valid
expect_pass "worldgen external feature refs strict" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/external-feature-refs \
  --strict
expect_fail_contains "worldgen invalid" "placed_feature references missing configured_feature" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/invalid
expect_pass "worldgen dimensions only" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/dimensions-only
expect_pass "worldgen dimensions only strict" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/dimensions-only \
  --strict
expect_pass "worldgen external dimension settings strict" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/external-dimension-settings \
  --strict
expect_pass "worldgen external dimension refs with tags strict" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/external-dimension-refs-with-tags \
  --strict
expect_fail_contains "worldgen invalid dimension refs type" "dimension references missing dimension_type" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/invalid-dimension-refs
expect_fail_contains "worldgen invalid dimension refs noise" "dimension references missing noise_settings" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/invalid-dimension-refs
expect_fail_contains "worldgen invalid external local dimension refs type" "dimension references missing dimension_type: minecraft:custom_missing" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/invalid-external-local-dimension-refs
expect_fail_contains "worldgen invalid external local dimension refs noise" "dimension references missing noise_settings: minecraft:custom_missing_noise" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/invalid-external-local-dimension-refs
expect_fail_contains "worldgen invalid dimension json summary" "worldgen validation failed" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/invalid-dimension-json
expect_fail_contains "worldgen invalid placed feature JSON" "invalid JSON" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/invalid-placed-json
expect_pass "worldgen nested paths" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/nested-paths
expect_fail_contains "worldgen invalid jigsaw start_pool" "jigsaw structure references missing template_pool" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/invalid-jigsaw-refs
expect_fail_contains "worldgen invalid jigsaw structure template" "template_pool element references missing structure template" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/invalid-jigsaw-refs
expect_fail_contains "worldgen invalid jigsaw processors" "template_pool element references missing processor_list" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/invalid-jigsaw-refs
expect_fail_contains "worldgen invalid tags" "invalid JSON" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/invalid-tags
expect_fail_contains "worldgen invalid tag layout" "invalid worldgen tag path" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/invalid-tag-layout
expect_fail_contains "worldgen empty" "no supported worldgen JSON files found" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/empty
expect_pass "worldgen tags only" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/tags-only
expect_pass "worldgen tags only strict" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/tags-only \
  --strict
expect_fail_contains "worldgen legacy path" "legacy path detected" \
  ./.agents/skills/minecraft-world-generation/scripts/validate-worldgen-json.sh \
  --root tests/fixtures/validators/worldgen/legacy

echo "$PASS all validator fixture checks completed"
