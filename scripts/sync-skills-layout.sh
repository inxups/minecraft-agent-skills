#!/usr/bin/env bash
set -euo pipefail

CANONICAL_DIR=".agents/skills"
MIRROR_DIR=".codex/skills"
MODE="${1:-sync}"

if [[ ! -d "$CANONICAL_DIR" ]]; then
  echo "[FAIL] Missing canonical directory: $CANONICAL_DIR" >&2
  exit 1
fi

mkdir -p "$MIRROR_DIR"

case "$MODE" in
  sync)
    rsync -a --delete "$CANONICAL_DIR/" "$MIRROR_DIR/"
    echo "[PASS] Synced $CANONICAL_DIR -> $MIRROR_DIR"
    ;;
  check)
    DIFF_OUTPUT="$(rsync -ani --delete "$CANONICAL_DIR/" "$MIRROR_DIR/")"
    if [[ -n "$DIFF_OUTPUT" ]]; then
      echo "[FAIL] Mirror drift detected between $CANONICAL_DIR and $MIRROR_DIR" >&2
      echo "$DIFF_OUTPUT" >&2
      exit 1
    fi
    echo "[PASS] Canonical and mirror trees are in sync"
    ;;
  *)
    echo "Usage: $0 [sync|check]" >&2
    exit 1
    ;;
esac
