#!/usr/bin/env bash
set -euo pipefail

PASS='[PASS]'
WARN='[WARN]'
FAIL='[FAIL]'

ROOT='.'
STRICT=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --root)
      if [[ $# -lt 2 || -z "${2:-}" ]]; then
        echo "$FAIL --root requires a path" >&2
        exit 2
      fi
      ROOT="$2"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: validate-test-layout.sh [--root <path>] [--strict]

Checks Minecraft 26.2 test layouts:
- build.gradle(.kts) exists
- src/test/java or src/test/kotlin exists
- the test task enables JUnit Platform
- test_instance and test_environment resources contain valid JSON
- local GameTest structure and environment references resolve
- Java-backed tests use RegisterGameTestsEvent
- removed annotation-based GameTest APIs are absent
USAGE
      exit 0
      ;;
    *)
      echo "$FAIL unknown arg: $1" >&2
      exit 2
      ;;
  esac
done

if [[ ! -d "$ROOT" ]]; then
  echo "$FAIL root path does not exist: $ROOT" >&2
  exit 1
fi

FAILURES=0
WARNINGS=0

pass() { echo "$PASS $*"; }
warn() { echo "$WARN $*"; WARNINGS=$((WARNINGS + 1)); }
fail() { echo "$FAIL $*"; FAILURES=$((FAILURES + 1)); }

relative_path() {
  local path="$1"
  printf '%s\n' "${path#"$ROOT"/}"
}

split_reference() {
  local source_namespace="$1"
  local reference="$2"
  if [[ "$reference" == *:* ]]; then
    printf '%s\n' "$reference"
  else
    printf '%s:%s\n' "$source_namespace" "$reference"
  fi
}

valid_identifier() {
  [[ "$1" =~ ^[a-z0-9_.-]+:[a-z0-9_./-]+$ ]]
}

reference_file_exists() {
  local identifier="$1"
  local registry="$2"
  local extension="$3"
  local namespace="${identifier%%:*}"
  local path="${identifier#*:}"
  local resource_root

  for resource_root in "${RESOURCE_ROOTS[@]-}"; do
    if [[ -f "$resource_root/data/$namespace/$registry/$path.$extension" ]]; then
      return 0
    fi
  done
  return 1
}

inspect_test_instance() {
  local file="$1"
  node - "$file" <<'NODE'
const fs = require("node:fs");
const file = process.argv[2];

try {
  const value = JSON.parse(fs.readFileSync(file, "utf8"));
  if (!value || Array.isArray(value) || typeof value !== "object") {
    throw new Error("root must be an object");
  }
  for (const field of ["type", "environment", "structure"]) {
    if (typeof value[field] !== "string" || value[field].length === 0) {
      throw new Error(`.${field} must be a non-empty string`);
    }
  }
  if (!Number.isInteger(value.max_ticks) || value.max_ticks <= 0) {
    throw new Error(".max_ticks must be a positive integer");
  }
  if (value.type === "minecraft:function" &&
      (typeof value.function !== "string" || value.function.length === 0)) {
    throw new Error("minecraft:function instance requires a non-empty .function");
  }
  process.stdout.write([
    value.type,
    value.environment,
    value.structure
  ].join("\t"));
} catch (error) {
  process.stderr.write(error.message);
  process.exit(1);
}
NODE
}

inspect_test_environment() {
  local file="$1"
  node - "$file" <<'NODE'
const fs = require("node:fs");
const file = process.argv[2];

try {
  const value = JSON.parse(fs.readFileSync(file, "utf8"));
  if (!value || Array.isArray(value) || typeof value !== "object") {
    throw new Error("root must be an object");
  }
  if (typeof value.type !== "string" || value.type.length === 0) {
    throw new Error(".type must be a non-empty string");
  }
} catch (error) {
  process.stderr.write(error.message);
  process.exit(1);
}
NODE
}

BUILD_FILE=''
if [[ -f "$ROOT/build.gradle.kts" ]]; then
  BUILD_FILE="$ROOT/build.gradle.kts"
elif [[ -f "$ROOT/build.gradle" ]]; then
  BUILD_FILE="$ROOT/build.gradle"
else
  fail "missing build.gradle or build.gradle.kts"
fi

declare -a TEST_SOURCE_ROOTS=()
for candidate in "$ROOT/src/test/java" "$ROOT/src/test/kotlin"; do
  if [[ -d "$candidate" ]]; then
    TEST_SOURCE_ROOTS+=("$candidate")
  fi
done

if [[ "${#TEST_SOURCE_ROOTS[@]}" -eq 0 ]]; then
  fail "missing src/test/java or src/test/kotlin"
else
  for test_root in "${TEST_SOURCE_ROOTS[@]}"; do
    pass "found test source root: $(relative_path "$test_root")"
  done
fi

if [[ -n "$BUILD_FILE" ]]; then
  pass "found build file: $(relative_path "$BUILD_FILE")"
  if grep -Eq 'useJUnitPlatform' "$BUILD_FILE"; then
    pass "test task enables JUnit Platform"
  else
    fail "test task missing useJUnitPlatform()"
  fi
fi

declare -a SOURCE_ROOTS=()
for candidate in \
  "$ROOT/src/main/java" \
  "$ROOT/src/main/kotlin" \
  "$ROOT/src/test/java" \
  "$ROOT/src/test/kotlin"; do
  if [[ -d "$candidate" ]]; then
    SOURCE_ROOTS+=("$candidate")
  fi
done

declare -a RESOURCE_ROOTS=()
for candidate in \
  "$ROOT/src/main/resources" \
  "$ROOT/src/generated/resources" \
  "$ROOT/src/test/resources"; do
  if [[ -d "$candidate" ]]; then
    RESOURCE_ROOTS+=("$candidate")
  fi
done

HAS_JAVA_GAMETESTS=0
HAS_REGISTER_EVENT=0
HAS_CUSTOM_INSTANCE=0
HAS_INSTANCE_TYPE_REGISTRATION=0
LEGACY_API_FILES=0

if [[ "${#SOURCE_ROOTS[@]}" -gt 0 ]]; then
  while IFS= read -r -d '' source_file; do
    if grep -Eq 'net\.minecraft\.gametest\.framework\.Game(Test);|GameTest(Hol)der|PrefixGame(Test)Template|@Game(Test)([[:space:](]|$)' "$source_file"; then
      fail "removed annotation-based GameTest API detected: $(relative_path "$source_file")"
      LEGACY_API_FILES=$((LEGACY_API_FILES + 1))
    fi

    if grep -Eq 'GameTestHelper|extends[[:space:]]+GameTestInstance' "$source_file"; then
      HAS_JAVA_GAMETESTS=1
    fi
    if grep -q 'RegisterGameTestsEvent' "$source_file"; then
      HAS_REGISTER_EVENT=1
    fi
    if grep -Eq 'extends[[:space:]]+GameTestInstance' "$source_file"; then
      HAS_CUSTOM_INSTANCE=1
    fi
    if grep -q 'Registries.TEST_INSTANCE_TYPE' "$source_file"; then
      HAS_INSTANCE_TYPE_REGISTRATION=1
    fi
  done < <(find "${SOURCE_ROOTS[@]}" -type f \( -name '*.java' -o -name '*.kt' \) -print0)
fi

if [[ "$HAS_JAVA_GAMETESTS" -eq 1 ]]; then
  pass "Java-backed GameTest sources detected"
  if [[ "$HAS_REGISTER_EVENT" -eq 1 ]]; then
    pass "RegisterGameTestsEvent registration detected"
  else
    fail "Java-backed GameTests require RegisterGameTestsEvent registration"
  fi
fi

if [[ "$HAS_CUSTOM_INSTANCE" -eq 1 ]]; then
  if [[ "$HAS_INSTANCE_TYPE_REGISTRATION" -eq 1 ]]; then
    pass "custom GameTestInstance type registry detected"
  else
    fail "custom GameTestInstance is missing Registries.TEST_INSTANCE_TYPE registration"
  fi
fi

if ! command -v node >/dev/null 2>&1; then
  fail "node is required to parse GameTest JSON resources"
fi

TEST_INSTANCE_COUNT=0
TEST_ENVIRONMENT_COUNT=0

if command -v node >/dev/null 2>&1 && [[ "${#RESOURCE_ROOTS[@]}" -gt 0 ]]; then
  while IFS= read -r -d '' environment_file; do
    TEST_ENVIRONMENT_COUNT=$((TEST_ENVIRONMENT_COUNT + 1))
    error_file="${TMPDIR:-/tmp}/minecraft-test-validator-env-$$.log"
    if inspect_test_environment "$environment_file" 2>"$error_file"; then
      pass "valid test_environment JSON: $(relative_path "$environment_file")"
    else
      fail "invalid test_environment JSON: $(relative_path "$environment_file") ($(tr '\n' ' ' < "$error_file"))"
    fi
    rm -f "$error_file"
  done < <(find "${RESOURCE_ROOTS[@]}" -type f -path '*/data/*/test_environment/*.json' -print0)

  while IFS= read -r -d '' instance_file; do
    TEST_INSTANCE_COUNT=$((TEST_INSTANCE_COUNT + 1))
    error_file="${TMPDIR:-/tmp}/minecraft-test-validator-instance-$$.log"
    if details="$(inspect_test_instance "$instance_file" 2>"$error_file")"; then
      pass "valid test_instance JSON: $(relative_path "$instance_file")"
    else
      fail "invalid test_instance JSON: $(relative_path "$instance_file") ($(tr '\n' ' ' < "$error_file"))"
      rm -f "$error_file"
      continue
    fi
    rm -f "$error_file"

    rel="${instance_file#*/data/}"
    source_namespace="${rel%%/*}"
    IFS=$'\t' read -r instance_type environment_ref structure_ref <<<"$details"

    environment_id="$(split_reference "$source_namespace" "$environment_ref")"
    structure_id="$(split_reference "$source_namespace" "$structure_ref")"

    if ! valid_identifier "$environment_id"; then
      fail "invalid GameTest environment identifier: $environment_ref"
    elif [[ "${environment_id%%:*}" == "$source_namespace" ]]; then
      if reference_file_exists "$environment_id" 'test_environment' 'json'; then
        pass "GameTest environment target exists: $environment_id"
      elif [[ "$HAS_REGISTER_EVENT" -eq 1 ]]; then
        pass "GameTest environment may be registered programmatically: $environment_id"
      else
        fail "GameTest references missing test_environment: $environment_id"
      fi
    fi

    if ! valid_identifier "$structure_id"; then
      fail "invalid GameTest structure identifier: $structure_ref"
    elif [[ "${structure_id%%:*}" == "$source_namespace" ]]; then
      if reference_file_exists "$structure_id" 'structure' 'nbt'; then
        pass "GameTest structure fixture exists: $structure_id"
      else
        fail "GameTest structure fixture missing: $structure_id"
      fi
    fi
  done < <(find "${RESOURCE_ROOTS[@]}" -type f -path '*/data/*/test_instance/*.json' -print0)
fi

HAS_GAMETESTS=0
if [[ "$HAS_JAVA_GAMETESTS" -eq 1 || "$TEST_INSTANCE_COUNT" -gt 0 || "$TEST_ENVIRONMENT_COUNT" -gt 0 ]]; then
  HAS_GAMETESTS=1
fi

if [[ "$HAS_GAMETESTS" -eq 1 ]]; then
  if [[ -f "$ROOT/src/main/resources/META-INF/neoforge.mods.toml" ]]; then
    pass "NeoForge metadata found for GameTests"
  else
    fail "GameTests detected but src/main/resources/META-INF/neoforge.mods.toml is missing"
  fi

  if [[ "$HAS_JAVA_GAMETESTS" -eq 1 && "$TEST_INSTANCE_COUNT" -eq 0 ]]; then
    if find "${RESOURCE_ROOTS[@]}" -type f -path '*/data/*/structure/*.nbt' 2>/dev/null | grep -q .; then
      warn "programmatic GameTest structure references cannot be matched statically"
    else
      fail "Java-backed GameTests have no committed data/*/structure/*.nbt fixture"
    fi
  fi
fi

echo ""
if [[ "$FAILURES" -gt 0 ]]; then
  echo "$FAIL testing layout validation failed with $FAILURES error(s) and $WARNINGS warning(s)"
  exit 1
fi

if [[ "$STRICT" -eq 1 && "$WARNINGS" -gt 0 ]]; then
  echo "$FAIL testing layout validation strict mode failed on $WARNINGS warning(s)"
  exit 1
fi

echo "$PASS testing layout validation passed with $WARNINGS warning(s)"
