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
Usage: validate-worldgen-json.sh [--root <path>] [--strict]

Checks worldgen JSON integrity:
- validates JSON under data/**/worldgen, data/**/dimension, data/**/dimension_type, data/**/tags/worldgen, and data/**/neoforge/biome_modifier
- validates key directory conventions
- validates local cross-references:
  dimension -> dimension_type + noise_settings
  placed_feature -> configured_feature
  structure_set -> structure
  jigsaw structure -> template_pool
  template_pool single_pool_element -> structure template + processor_list
  biome and biome_modifier feature references -> placed_feature
USAGE
      exit 0
      ;;
    *)
      echo "$FAIL unknown arg: $1" >&2
      exit 1
      ;;
  esac
done

if [[ "${WORLDGEN_FORCE_JQ_SHIM:-0}" == "1" ]] || ! command -v jq >/dev/null 2>&1; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  JQ_SHIM="$SCRIPT_DIR/jq-shim.mjs"
  if command -v node >/dev/null 2>&1 && [[ -f "$JQ_SHIM" ]]; then
    jq() {
      node "$JQ_SHIM" "$@"
    }
  else
    echo "$FAIL jq is required"
    exit 1
  fi
fi

if [[ ! -d "$ROOT" ]]; then
  echo "$FAIL root path does not exist: $ROOT"
  exit 1
fi

FAILURES=0
WARNINGS=0

pass() { echo "$PASS $*"; }
warn() { echo "$WARN $*"; WARNINGS=$((WARNINGS + 1)); }
fail() { echo "$FAIL $*"; FAILURES=$((FAILURES + 1)); }
strip_cr() { printf '%s' "${1%$'\r'}"; }
json_query_raw() {
  local filter="$1"
  local file="$2"

  jq -r "$filter" "$file"
}

TOTAL_SUPPORTED_FILES=0

declare -a VALIDATED_JSON_FILES=()
declare -a INVALID_JSON_FILES=()
declare -a CONFIGURED_FEATURES=()
declare -a PLACED_FEATURES=()
declare -a STRUCTURES=()
declare -a TEMPLATE_POOLS=()
declare -a PROCESSOR_LISTS=()
declare -a STRUCTURE_TEMPLATES=()
declare -a STRUCTURE_TAGS=()
declare -a DIMENSION_TYPES=()
declare -a NOISE_SETTINGS=()

DATA_ROOT="$ROOT/data"

BIOME_FILES=0
BIOME_MODIFIER_FILES=0

contains_value() {
  local needle="$1"
  shift
  local value
  for value in "$@"; do
    if [[ "$value" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

is_vanilla_template_pool() {
  [[ "$1" == "minecraft:empty" ]]
}

is_vanilla_processor_list() {
  [[ "$1" == "minecraft:empty" ]]
}

is_vanilla_dimension_type() {
  case "$1" in
    minecraft:overworld|minecraft:overworld_caves|minecraft:the_nether|minecraft:the_end) return 0 ;;
    *) return 1 ;;
  esac
}

is_vanilla_noise_settings() {
  case "$1" in
    minecraft:overworld|minecraft:large_biomes|minecraft:amplified|minecraft:nether|minecraft:end|minecraft:caves|minecraft:floating_islands) return 0 ;;
    *) return 1 ;;
  esac
}

to_id() {
  local file="$1"
  local rel ns path noext
  rel="${file#"$ROOT/data/"}"
  ns="${rel%%/*}"
  path="${rel#*/}"
  path="${path#worldgen/}"
  noext="${path%.json}"
  noext="${noext%.nbt}"
  echo "$ns:${noext#*/}"
}

split_ref() {
  local default_ns="$1"
  local ref="$2"
  if [[ "$ref" == *:* ]]; then
    echo "$ref"
  else
    echo "$default_ns:$ref"
  fi
}

check_json() {
  local file="$1"
  if jq empty "$file" >/dev/null 2>&1; then
    pass "valid JSON: ${file#$ROOT/}"
  else
    INVALID_JSON_FILES+=("$file")
    fail "invalid JSON: ${file#$ROOT/}"
  fi
}

check_json_once() {
  local file="$1"
  if contains_value "$file" "${VALIDATED_JSON_FILES[@]-}"; then
    return
  fi

  VALIDATED_JSON_FILES+=("$file")
  check_json "$file"
  TOTAL_SUPPORTED_FILES=$((TOTAL_SUPPORTED_FILES + 1))
}

should_validate_dimension_type_ref() {
  local source_ns="$1"
  local id="$2"
  local target_ns="${id%%:*}"

  if [[ "$target_ns" == "$source_ns" ]]; then
    return 0
  fi

  if [[ "$target_ns" == "minecraft" ]] && is_vanilla_dimension_type "$id"; then
    return 1
  fi

  [[ -d "$DATA_ROOT/$target_ns/dimension_type" ]]
}

should_validate_noise_settings_ref() {
  local source_ns="$1"
  local id="$2"
  local target_ns="${id%%:*}"

  if [[ "$target_ns" == "$source_ns" ]]; then
    return 0
  fi

  if [[ "$target_ns" == "minecraft" ]] && is_vanilla_noise_settings "$id"; then
    return 1
  fi

  [[ -d "$DATA_ROOT/$target_ns/worldgen/noise_settings" ]]
}

find_worldgen_jsons() {
  local category="${1:-}"
  while IFS= read -r -d '' worldgen_dir; do
    if [[ -n "$category" ]]; then
      [[ -d "$worldgen_dir/$category" ]] || continue
      find "$worldgen_dir/$category" -mindepth 1 -type f -name '*.json' -print0 2>/dev/null
    else
      find "$worldgen_dir" -mindepth 2 -type f -name '*.json' -print0 2>/dev/null
    fi
  done < <(find "$DATA_ROOT" -mindepth 2 -maxdepth 2 -type d -name worldgen -print0 2>/dev/null)
}

find_namespace_jsons() {
  local dir_name="$1"
  while IFS= read -r -d '' dir; do
    find "$dir" -mindepth 1 -type f -name '*.json' -print0 2>/dev/null
  done < <(find "$DATA_ROOT" -mindepth 2 -maxdepth 2 -type d -name "$dir_name" -print0 2>/dev/null)
}

find_neoforge_jsons() {
  local dir_name="$1"
  while IFS= read -r -d '' dir; do
    find "$dir" -mindepth 1 -type f -name '*.json' -print0 2>/dev/null
  done < <(find "$DATA_ROOT" -mindepth 3 -maxdepth 3 -type d -path "$DATA_ROOT/*/neoforge/$dir_name" -print0 2>/dev/null)
}

find_structure_templates() {
  while IFS= read -r -d '' dir; do
    find "$dir" -mindepth 1 -type f -name '*.nbt' -print0 2>/dev/null
  done < <(find "$DATA_ROOT" -mindepth 2 -maxdepth 2 -type d -name structure -print0 2>/dev/null)
}

find_tags_worldgen_jsons() {
  while IFS= read -r -d '' dir; do
    find "$dir" -mindepth 2 -type f -name '*.json' -print0 2>/dev/null
  done < <(find "$DATA_ROOT" -mindepth 3 -maxdepth 3 -type d -path "$DATA_ROOT/*/tags/worldgen" -print0 2>/dev/null)
}

find_worldgen_tag_jsons() {
  local registry="$1"
  while IFS= read -r -d '' dir; do
    find "$dir/$registry" -mindepth 1 -type f -name '*.json' -print0 2>/dev/null
  done < <(find "$DATA_ROOT" -mindepth 3 -maxdepth 3 -type d -path "$DATA_ROOT/*/tags/worldgen" -print0 2>/dev/null)
}

to_worldgen_tag_id() {
  local file="$1"
  local registry="$2"
  local rel ns path
  rel="${file#"$ROOT/data/"}"
  ns="${rel%%/*}"
  path="${rel#*/tags/worldgen/$registry/}"
  echo "$ns:${path%.json}"
}

find_invalid_tags_worldgen_jsons() {
  while IFS= read -r -d '' dir; do
    find "$dir" -mindepth 1 -maxdepth 1 -type f -name '*.json' -print0 2>/dev/null
  done < <(find "$DATA_ROOT" -mindepth 3 -maxdepth 3 -type d -path "$DATA_ROOT/*/tags/worldgen" -print0 2>/dev/null)
}

should_validate_template_pool_ref() {
  local source_ns="$1"
  local id="$2"
  local target_ns="${id%%:*}"

  if [[ "$target_ns" == "$source_ns" ]]; then
    return 0
  fi

  if [[ "$target_ns" == "minecraft" ]] && is_vanilla_template_pool "$id"; then
    return 1
  fi

  [[ -d "$DATA_ROOT/$target_ns/worldgen/template_pool" ]]
}

should_validate_processor_list_ref() {
  local source_ns="$1"
  local id="$2"
  local target_ns="${id%%:*}"

  if [[ "$target_ns" == "$source_ns" ]]; then
    return 0
  fi

  if [[ "$target_ns" == "minecraft" ]] && is_vanilla_processor_list "$id"; then
    return 1
  fi

  [[ -d "$DATA_ROOT/$target_ns/worldgen/processor_list" ]]
}

should_validate_structure_template_ref() {
  local source_ns="$1"
  local id="$2"
  local target_ns="${id%%:*}"

  if [[ "$target_ns" == "$source_ns" ]]; then
    return 0
  fi

  [[ -d "$DATA_ROOT/$target_ns/structure" ]]
}

should_validate_worldgen_ref() {
  local source_ns="$1"
  local id="$2"
  local registry="$3"
  local target_ns="${id%%:*}"

  if [[ "$target_ns" == "$source_ns" ]]; then
    return 0
  fi

  [[ -d "$DATA_ROOT/$target_ns/worldgen/$registry" ]]
}

should_validate_worldgen_tag_ref() {
  local source_ns="$1"
  local id="$2"
  local registry="$3"
  local target_ns="${id%%:*}"

  if [[ "$target_ns" == "$source_ns" ]]; then
    return 0
  fi

  [[ -d "$DATA_ROOT/$target_ns/tags/worldgen/$registry" ]]
}

echo "=== Worldgen Validator ==="

if [[ ! -d "$DATA_ROOT" ]]; then
  fail "missing data/ directory"
fi

echo "Checking for legacy paths..."
while IFS= read -r -d '' legacy_path; do
  fail "legacy path detected: ${legacy_path#$ROOT/}"
done < <(find_neoforge_jsons 'biome_modifiers')

while IFS= read -r -d '' invalid_tag_path; do
  fail "invalid worldgen tag path: ${invalid_tag_path#$ROOT/} (expected tags/worldgen/<registry>/...)"
done < <(find_invalid_tags_worldgen_jsons)

while IFS= read -r -d '' f; do
  check_json_once "$f"
done < <(
  {
    find_worldgen_jsons
    find_namespace_jsons 'dimension'
    find_namespace_jsons 'dimension_type'
    find_tags_worldgen_jsons
    find_neoforge_jsons 'biome_modifier'
  }
)

while IFS= read -r -d '' f; do
  id="$(to_id "$f")"
  CONFIGURED_FEATURES+=("$id")
done < <(find_worldgen_jsons 'configured_feature')

while IFS= read -r -d '' f; do
  id="$(to_id "$f")"
  PLACED_FEATURES+=("$id")
done < <(find_worldgen_jsons 'placed_feature')

while IFS= read -r -d '' f; do
  id="$(to_id "$f")"
  STRUCTURES+=("$id")
done < <(find_worldgen_jsons 'structure')

while IFS= read -r -d '' f; do
  id="$(to_id "$f")"
  TEMPLATE_POOLS+=("$id")
done < <(find_worldgen_jsons 'template_pool')

while IFS= read -r -d '' f; do
  id="$(to_id "$f")"
  PROCESSOR_LISTS+=("$id")
done < <(find_worldgen_jsons 'processor_list')

while IFS= read -r -d '' f; do
  id="$(to_id "$f")"
  STRUCTURE_TEMPLATES+=("$id")
done < <(find_structure_templates)

while IFS= read -r -d '' f; do
  id="$(to_worldgen_tag_id "$f" 'structure')"
  STRUCTURE_TAGS+=("$id")
done < <(find_worldgen_tag_jsons 'structure')

while IFS= read -r -d '' f; do
  id="$(to_id "$f")"
  DIMENSION_TYPES+=("$id")
done < <(find_namespace_jsons 'dimension_type')

while IFS= read -r -d '' f; do
  id="$(to_id "$f")"
  NOISE_SETTINGS+=("$id")
done < <(find_worldgen_jsons 'noise_settings')

while IFS= read -r -d '' _; do
  BIOME_FILES=$((BIOME_FILES + 1))
done < <(find_worldgen_jsons 'biome')

while IFS= read -r -d '' _; do
  BIOME_MODIFIER_FILES=$((BIOME_MODIFIER_FILES + 1))
done < <(find_neoforge_jsons 'biome_modifier')

if [[ "$TOTAL_SUPPORTED_FILES" -eq 0 ]]; then
  fail "no supported worldgen JSON files found under data/**/worldgen, data/**/dimension, data/**/dimension_type, data/**/tags/worldgen, or data/**/neoforge/biome_modifier"
fi

if (( ${#PLACED_FEATURES[@]} == 0 && (BIOME_FILES > 0 || BIOME_MODIFIER_FILES > 0) )); then
  warn "no placed_feature JSON files found"
fi

if (( ${#CONFIGURED_FEATURES[@]} == 0 && ${#PLACED_FEATURES[@]} > 0 )); then
  warn "no configured_feature JSON files found"
fi

echo "Checking dimension references..."
while IFS= read -r -d '' dimension_file; do
  if contains_value "$dimension_file" "${INVALID_JSON_FILES[@]-}"; then
    continue
  fi

  rel="${dimension_file#"$ROOT/data/"}"
  ns="${rel%%/*}"
  type_ref="$(jq -r '.type? // empty' "$dimension_file")"
  type_ref="$(strip_cr "$type_ref")"

  if [[ -z "$type_ref" ]]; then
    fail "dimension missing .type: ${dimension_file#$ROOT/}"
  else
    type_id="$(split_ref "$ns" "$type_ref")"
    if should_validate_dimension_type_ref "$ns" "$type_id"; then
      if contains_value "$type_id" "${DIMENSION_TYPES[@]-}"; then
        pass "dimension type target exists: $type_id"
      else
        fail "dimension references missing dimension_type: $type_id"
      fi
    fi
  fi

  settings_ref="$(jq -r 'if (.generator?.type? // empty) == "minecraft:noise" and (.generator?.settings? | type) == "string" then .generator.settings else empty end' "$dimension_file")"
  settings_ref="$(strip_cr "$settings_ref")"
  if [[ -z "$settings_ref" ]]; then
    continue
  fi

  settings_id="$(split_ref "$ns" "$settings_ref")"
  if ! should_validate_noise_settings_ref "$ns" "$settings_id"; then
    continue
  fi

  if contains_value "$settings_id" "${NOISE_SETTINGS[@]-}"; then
    pass "dimension noise settings target exists: $settings_id"
  else
    fail "dimension references missing noise_settings: $settings_id"
  fi
done < <(find_namespace_jsons 'dimension')

echo "Checking placed_feature -> configured_feature references..."
while IFS= read -r -d '' pf_file; do
  if contains_value "$pf_file" "${INVALID_JSON_FILES[@]-}"; then
    continue
  fi

  rel="${pf_file#"$ROOT/data/"}"
  ns="${rel%%/*}"
  feature_ref="$(jq -r '.feature? // empty' "$pf_file")"
  feature_ref="$(strip_cr "$feature_ref")"

  if [[ -z "$feature_ref" ]]; then
    fail "placed_feature missing .feature: ${pf_file#$ROOT/}"
    continue
  fi

  if [[ "$feature_ref" == \#* ]]; then
    warn "tag reference not resolved in placed_feature: ${pf_file#$ROOT/} -> $feature_ref"
    continue
  fi

  feature_id="$(split_ref "$ns" "$feature_ref")"
  if ! should_validate_worldgen_ref "$ns" "$feature_id" 'configured_feature'; then
    continue
  fi

  if contains_value "$feature_id" "${CONFIGURED_FEATURES[@]-}"; then
    pass "placed_feature target exists: $feature_id"
  else
    fail "placed_feature references missing configured_feature: $feature_id"
  fi
done < <(find_worldgen_jsons 'placed_feature')

echo "Checking structure_set -> structure references..."
while IFS= read -r -d '' ss_file; do
  if contains_value "$ss_file" "${INVALID_JSON_FILES[@]-}"; then
    continue
  fi

  rel="${ss_file#"$ROOT/data/"}"
  ns="${rel%%/*}"
  while IFS= read -r sref; do
    sref="$(strip_cr "$sref")"
    [[ -z "$sref" ]] && continue

    if [[ "$sref" == \#* ]]; then
      tag_id="$(split_ref "$ns" "${sref#\#}")"
      if ! should_validate_worldgen_tag_ref "$ns" "$tag_id" 'structure'; then
        continue
      fi
      if contains_value "$tag_id" "${STRUCTURE_TAGS[@]-}"; then
        pass "structure_set tag target exists: #$tag_id"
      else
        fail "structure_set references missing structure tag: #$tag_id"
      fi
      continue
    fi

    sid="$(split_ref "$ns" "$sref")"
    if ! should_validate_worldgen_ref "$ns" "$sid" 'structure'; then
      continue
    fi
    if contains_value "$sid" "${STRUCTURES[@]-}"; then
      pass "structure_set target exists: $sid"
    else
      fail "structure_set references missing structure: $sid"
    fi
  done < <(jq -r '.structures[]?.structure? // empty' "$ss_file")
done < <(find_worldgen_jsons 'structure_set')

echo "Checking jigsaw structure and template_pool references..."
while IFS= read -r -d '' structure_file; do
  if contains_value "$structure_file" "${INVALID_JSON_FILES[@]-}"; then
    continue
  fi

  rel="${structure_file#"$ROOT/data/"}"
  ns="${rel%%/*}"
  structure_type="$(json_query_raw '.type? // empty' "$structure_file")"
  structure_type="$(strip_cr "$structure_type")"

  if [[ "$structure_type" != "minecraft:jigsaw" ]]; then
    continue
  fi

  start_pool_ref="$(json_query_raw '.start_pool? // empty' "$structure_file")"
  start_pool_ref="$(strip_cr "$start_pool_ref")"

  if [[ -z "$start_pool_ref" ]]; then
    fail "jigsaw structure missing .start_pool: ${structure_file#$ROOT/}"
    continue
  fi

  start_pool_id="$(split_ref "$ns" "$start_pool_ref")"
  if should_validate_template_pool_ref "$ns" "$start_pool_id"; then
    if contains_value "$start_pool_id" "${TEMPLATE_POOLS[@]-}"; then
      pass "jigsaw start_pool target exists: $start_pool_id"
    else
      fail "jigsaw structure references missing template_pool: $start_pool_id"
    fi
  fi
done < <(find_worldgen_jsons 'structure')

while IFS= read -r -d '' pool_file; do
  if contains_value "$pool_file" "${INVALID_JSON_FILES[@]-}"; then
    continue
  fi

  rel="${pool_file#"$ROOT/data/"}"
  ns="${rel%%/*}"
  while IFS=$'\t' read -r location_ref processors_ref; do
    location_ref="$(strip_cr "$location_ref")"
    processors_ref="$(strip_cr "$processors_ref")"

    if [[ -z "$location_ref" ]]; then
      fail "template_pool single_pool_element missing .location: ${pool_file#$ROOT/}"
    else
      location_id="$(split_ref "$ns" "$location_ref")"
      if should_validate_structure_template_ref "$ns" "$location_id"; then
        if contains_value "$location_id" "${STRUCTURE_TEMPLATES[@]-}"; then
          pass "template_pool structure template target exists: $location_id"
        else
          fail "template_pool element references missing structure template: $location_id"
        fi
      fi
    fi

    if [[ -z "$processors_ref" ]]; then
      fail "template_pool single_pool_element missing .processors: ${pool_file#$ROOT/}"
    else
      processors_id="$(split_ref "$ns" "$processors_ref")"
      if should_validate_processor_list_ref "$ns" "$processors_id"; then
        if contains_value "$processors_id" "${PROCESSOR_LISTS[@]-}"; then
          pass "template_pool processor_list target exists: $processors_id"
        else
          fail "template_pool element references missing processor_list: $processors_id"
        fi
      fi
    fi
  done < <(json_query_raw '
    .. | objects
    | select(.element_type? == "minecraft:single_pool_element" or .element_type? == "minecraft:legacy_single_pool_element")
    | [(.location? // ""), (.processors? // "")]
    | @tsv
  ' "$pool_file")
done < <(find_worldgen_jsons 'template_pool')

echo "Checking biome feature references..."
while IFS= read -r -d '' biome_file; do
  if contains_value "$biome_file" "${INVALID_JSON_FILES[@]-}"; then
    continue
  fi

  rel="${biome_file#"$ROOT/data/"}"
  ns="${rel%%/*}"
  while IFS= read -r fref; do
    fref="$(strip_cr "$fref")"
    [[ -z "$fref" ]] && continue
    if [[ "$fref" == \#* ]]; then
      warn "tag reference not resolved in biome file: ${biome_file#$ROOT/} -> $fref"
      continue
    fi

    fid="$(split_ref "$ns" "$fref")"
    if ! should_validate_worldgen_ref "$ns" "$fid" 'placed_feature'; then
      continue
    fi
    if contains_value "$fid" "${PLACED_FEATURES[@]-}"; then
      pass "biome feature target exists: $fid"
    else
      fail "biome references missing placed_feature: $fid"
    fi
  done < <(jq -r '.features[][]? // empty' "$biome_file")
done < <(find_worldgen_jsons 'biome')

echo "Checking biome_modifier feature/structure references..."
while IFS= read -r -d '' mod_file; do
  if contains_value "$mod_file" "${INVALID_JSON_FILES[@]-}"; then
    continue
  fi

  rel="${mod_file#"$ROOT/data/"}"
  ns="${rel%%/*}"

  while IFS= read -r ref; do
    ref="$(strip_cr "$ref")"
    [[ -z "$ref" ]] && continue
    if [[ "$ref" == \#* ]]; then
      warn "tag reference not resolved in biome_modifier: ${mod_file#$ROOT/} -> $ref"
      continue
    fi

    rid="$(split_ref "$ns" "$ref")"
    if ! should_validate_worldgen_ref "$ns" "$rid" 'placed_feature'; then
      continue
    fi
    if contains_value "$rid" "${PLACED_FEATURES[@]-}"; then
      pass "biome_modifier feature target exists: $rid"
    else
      fail "biome_modifier references missing placed_feature: $rid"
    fi
  done < <(jq -r '(.features? // empty) | if type == "array" then .[] else . end' "$mod_file")

  while IFS= read -r ref; do
    ref="$(strip_cr "$ref")"
    [[ -z "$ref" ]] && continue

    if [[ "$ref" == \#* ]]; then
      tag_id="$(split_ref "$ns" "${ref#\#}")"
      if ! should_validate_worldgen_tag_ref "$ns" "$tag_id" 'structure'; then
        continue
      fi
      if contains_value "$tag_id" "${STRUCTURE_TAGS[@]-}"; then
        pass "biome_modifier structure tag target exists: #$tag_id"
      else
        fail "biome_modifier references missing structure tag: #$tag_id"
      fi
      continue
    fi

    rid="$(split_ref "$ns" "$ref")"
    if ! should_validate_worldgen_ref "$ns" "$rid" 'structure'; then
      continue
    fi
    if contains_value "$rid" "${STRUCTURES[@]-}"; then
      pass "biome_modifier structure target exists: $rid"
    else
      fail "biome_modifier references missing structure: $rid"
    fi
  done < <(jq -r '(.structures? // empty) | if type == "array" then .[] else . end' "$mod_file")
done < <(find_neoforge_jsons 'biome_modifier')

echo ""
if [[ "$FAILURES" -gt 0 ]]; then
  echo "$FAIL worldgen validation failed with $FAILURES error(s) and $WARNINGS warning(s)"
  exit 1
fi

if [[ "$STRICT" -eq 1 && "$WARNINGS" -gt 0 ]]; then
  echo "$FAIL worldgen validation strict mode failed on $WARNINGS warning(s)"
  exit 1
fi

echo "$PASS worldgen validation passed with $WARNINGS warning(s)"
