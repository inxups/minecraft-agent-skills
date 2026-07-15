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
      ROOT="${2:-}"
      shift 2
      ;;
    --strict)
      STRICT=1
      shift
      ;;
    --help|-h)
      cat <<'USAGE'
Usage: validate-test-layout.sh [--root <path>] [--strict]

Checks common 26.2 testing layout expectations:
- build.gradle(.kts) exists
- src/test/java or src/test/kotlin exists
- test task enables JUnit Platform
- GameTests have committed structure fixtures that match referenced templates
- NeoForge GameTests include their required registration metadata
USAGE
      exit 0
      ;;
    *)
      echo "$FAIL unknown arg: $1" >&2
      exit 1
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

extract_package_name() {
  local file="$1"
  awk '/^[[:space:]]*package[[:space:]]+/ { gsub(/;/, "", $2); print $2; exit }' "$file"
}

extract_class_name() {
  local file="$1"
  sed -nE 's/.*(^|[[:space:]])(class|object)[[:space:]]+([A-Za-z_][A-Za-z0-9_]*).*/\3/p' "$file" | head -n 1
}

extract_fqcn() {
  local file="$1"
  local package_name
  local class_name
  package_name="$(extract_package_name "$file")"
  class_name="$(extract_class_name "$file")"

  if [[ -z "$class_name" ]]; then
    return 1
  fi

  if [[ -n "$package_name" ]]; then
    printf '%s.%s\n' "$package_name" "$class_name"
  else
    printf '%s\n' "$class_name"
  fi
}

template_fixture_exists() {
  local root="$1"
  local namespace="$2"
  local path="$3"
  local structure_roots=()

  if [[ -d "$root/src/test/resources" ]]; then
    structure_roots+=("$root/src/test/resources")
  fi
  if [[ -d "$root/src/main/resources" ]]; then
    structure_roots+=("$root/src/main/resources")
  fi

  if [[ "${#structure_roots[@]}" -eq 0 ]]; then
    return 1
  fi

  local structure_rel="data/$namespace/structure/$path.nbt"
  local structure_root
  for structure_root in "${structure_roots[@]}"; do
    if [[ -f "$structure_root/$structure_rel" ]]; then
      return 0
    fi
  done

  return 1
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
if [[ -d "$ROOT/src/test/java" ]]; then
  TEST_SOURCE_ROOTS+=("$ROOT/src/test/java")
fi
if [[ -d "$ROOT/src/test/kotlin" ]]; then
  TEST_SOURCE_ROOTS+=("$ROOT/src/test/kotlin")
fi
if [[ "${#TEST_SOURCE_ROOTS[@]}" -eq 0 ]]; then
  fail "missing src/test/java or src/test/kotlin"
fi

if [[ -n "$BUILD_FILE" ]]; then
  pass "found build file: ${BUILD_FILE#$ROOT/}"
fi

if [[ "${#TEST_SOURCE_ROOTS[@]}" -gt 0 ]]; then
  for test_root in "${TEST_SOURCE_ROOTS[@]}"; do
    pass "found test source root: ${test_root#$ROOT/}"
  done
fi

if [[ -n "$BUILD_FILE" ]]; then
  if grep -Eq 'useJUnitPlatform' "$BUILD_FILE"; then
    pass "test task enables JUnit Platform"
  else
    fail "test task missing useJUnitPlatform()"
  fi
fi

HAS_GAMETESTS=0
declare -a SOURCE_SCAN_ROOTS=()
for candidate_root in \
  "$ROOT/src/main/java" \
  "$ROOT/src/main/kotlin" \
  "$ROOT/src/test/java" \
  "$ROOT/src/test/kotlin"; do
  if [[ -d "$candidate_root" ]]; then
    SOURCE_SCAN_ROOTS+=("$candidate_root")
  fi
done

declare -a GAME_TEST_FILES=()
declare -a GAME_TEST_TEMPLATES=()
declare -a NEOFORGE_GAMETEST_CLASSES=()
declare -a NON_LITERAL_TEMPLATE_FILES=()

if [[ "${#SOURCE_SCAN_ROOTS[@]}" -gt 0 ]]; then
  while IFS= read -r -d '' source_file; do
    if grep -E -q '@GameTest|GameTestHelper' "$source_file"; then
      GAME_TEST_FILES+=("$source_file")
      fqcn="$(extract_fqcn "$source_file" || true)"
      if [[ -n "$fqcn" ]]; then
        if grep -E -q 'net\.neoforged|@GameTestHolder|PrefixGameTestTemplate' "$source_file"; then
          NEOFORGE_GAMETEST_CLASSES+=("$fqcn")
        fi
      fi

      while IFS= read -r template; do
        [[ -n "$template" ]] && GAME_TEST_TEMPLATES+=("$template")
      done < <(grep -oE '@GameTest\([^)]*template[[:space:]]*=[[:space:]]*"[^"]+"' "$source_file" | sed -E 's/.*template[[:space:]]*=[[:space:]]*"([^"]+)"/\1/')

      annotation_count="$(grep -oE '@GameTest[[:space:]]*\(' "$source_file" | wc -l | tr -d ' ' || true)"
      literal_count="$(grep -oE '@GameTest\([^)]*template[[:space:]]*=[[:space:]]*"[^"]+"' "$source_file" | wc -l | tr -d ' ' || true)"
      if [[ "${annotation_count:-0}" -gt "${literal_count:-0}" ]]; then
        NON_LITERAL_TEMPLATE_FILES+=("$source_file")
      fi
    fi
  done < <(find "${SOURCE_SCAN_ROOTS[@]}" -type f \( -name '*.java' -o -name '*.kt' \) -print0)
fi

if [[ "${#GAME_TEST_FILES[@]}" -gt 0 ]]; then
  HAS_GAMETESTS=1
  pass "GameTest-style tests detected"
fi

if [[ "$HAS_GAMETESTS" -eq 1 ]]; then
  if [[ "${#GAME_TEST_TEMPLATES[@]}" -gt 0 ]]; then
    for template in "${GAME_TEST_TEMPLATES[@]}"; do
      if [[ "$template" =~ ^([a-z0-9_.-]+):([a-z0-9_./-]+)$ ]]; then
        if template_fixture_exists "$ROOT" "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"; then
          pass "GameTest template fixture exists: $template"
        else
          fail "GameTest template fixture missing: $template"
        fi
      else
        warn "GameTest template uses a non-literal or unsupported format: $template"
      fi
    done
  elif find "$ROOT/src" -type f -path '*/data/*/structure/*.nbt' 2>/dev/null | grep -q .; then
    pass "GameTest structure fixtures found"
  else
    fail "GameTest tests detected but no committed data/*/structure/*.nbt fixtures were found"
  fi

  if [[ "${#NON_LITERAL_TEMPLATE_FILES[@]}" -gt 0 ]]; then
    for source_file in "${NON_LITERAL_TEMPLATE_FILES[@]}"; do
      warn "GameTest template is non-literal and cannot be matched statically: ${source_file#$ROOT/}"
    done
  fi

  if [[ "${#NEOFORGE_GAMETEST_CLASSES[@]}" -eq 0 ]]; then
    warn "GameTest sources were found, but no NeoForge GameTest class could be identified"
  fi

  if [[ "${#NEOFORGE_GAMETEST_CLASSES[@]}" -gt 0 ]]; then
    if [[ -f "$ROOT/src/main/resources/META-INF/neoforge.mods.toml" ]]; then
      pass "NeoForge metadata found for GameTests"
    else
      fail "NeoForge GameTests detected but src/main/resources/META-INF/neoforge.mods.toml is missing"
    fi

    for fqcn in "${NEOFORGE_GAMETEST_CLASSES[@]}"; do
      class_name="${fqcn##*.}"
      if grep -R -E -q "register\\([[:space:]]*$class_name\\.class[[:space:]]*\\)" "$ROOT/src/main" "$ROOT/src/test" 2>/dev/null; then
        pass "NeoForge GameTest class is registered: $fqcn"
      else
        fail "NeoForge GameTest class is not registered on an event bus: $fqcn"
      fi
    done
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
