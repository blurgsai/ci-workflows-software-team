#!/usr/bin/env bash
#
# Validates that each feature folder has the required 4-layer structure:
#   api/types.ts         — Raw backend types (mirrors backend exactly)
#   api/<name>Api.ts     — Fetch functions
#   model/types.ts       — Domain types (YOUR types, YOUR naming)
#   model/mappers.ts     — Anti-corruption layer (translator)
#   hooks/use*.ts        — Data-fetching hooks (TanStack Query)
#   ui/*.tsx             — Presentational components (nested subfolders allowed)
#   index.ts             — Barrel export (public API)
#
# Usage: ./validate-feature-structure.sh <features_dir>
#
set -euo pipefail

FEATURES_DIR="${1:-src/features}"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist yet."
  echo "      This is OK if no features have been created."
  exit 0
fi

REQUIRED_SUBDIRS=("api" "model" "hooks" "ui")
ERRORS=0

echo "=========================================="
echo "  Feature Folder Structure Validation"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")
  echo ""
  echo "Feature: $feature_name"

  # Check if this is a scaffolded/empty feature (only .gitkeep files)
  real_file_count=$(find "$feature_dir" -type f -not -name ".gitkeep" -not -name "index.ts" | wc -l)
  if [ "$real_file_count" -eq 0 ]; then
    echo "  SKIP: Scaffolded feature (only .gitkeep placeholders) — no implementation yet"
    # Still check that required directories exist
    for subdir in "${REQUIRED_SUBDIRS[@]}"; do
      if [ ! -d "${feature_dir}${subdir}" ]; then
        echo "  FAIL: Missing required directory: ${subdir}/"
        ERRORS=$((ERRORS + 1))
      fi
    done
    if [ ! -f "${feature_dir}index.ts" ]; then
      echo "  FAIL: Missing barrel export: index.ts"
      ERRORS=$((ERRORS + 1))
    fi
    continue
  fi

  # Check for required subdirectories
  for subdir in "${REQUIRED_SUBDIRS[@]}"; do
    if [ ! -d "${feature_dir}${subdir}" ]; then
      echo "  FAIL: Missing required directory: ${subdir}/"
      ERRORS=$((ERRORS + 1))
    fi
  done

  # Check for barrel export index.ts
  if [ ! -f "${feature_dir}index.ts" ]; then
    echo "  FAIL: Missing barrel export: index.ts"
    ERRORS=$((ERRORS + 1))
  fi

  # Check api/ has types.ts (raw backend types)
  if [ -d "${feature_dir}api" ]; then
    # Skip content check if api/ only has .gitkeep
    api_real_files=$(find "${feature_dir}api" -maxdepth 1 -type f -not -name ".gitkeep" | wc -l)
    if [ "$api_real_files" -gt 0 ]; then
      if [ ! -f "${feature_dir}api/types.ts" ]; then
        echo "  FAIL: Missing api/types.ts (raw API types — must mirror backend exactly)"
        ERRORS=$((ERRORS + 1))
      fi

      # Check api/ has at least one fetch function file (*Api.ts)
      api_file_count=$(find "${feature_dir}api" -maxdepth 1 -name "*Api.ts" -o -name "*api.ts" | wc -l)
      if [ "$api_file_count" -eq 0 ]; then
        echo "  FAIL: No API fetch function file (*Api.ts) found in api/"
        ERRORS=$((ERRORS + 1))
      fi
    fi
  fi

  # Check model/ has types.ts and mappers.ts
  if [ -d "${feature_dir}model" ]; then
    model_real_files=$(find "${feature_dir}model" -maxdepth 1 -type f -not -name ".gitkeep" | wc -l)
    if [ "$model_real_files" -gt 0 ]; then
      if [ ! -f "${feature_dir}model/types.ts" ]; then
        echo "  FAIL: Missing model/types.ts (domain types — YOUR types, YOUR naming)"
        ERRORS=$((ERRORS + 1))
      fi
      if [ ! -f "${feature_dir}model/mappers.ts" ]; then
        echo "  FAIL: Missing model/mappers.ts (anti-corruption layer — the translator)"
        ERRORS=$((ERRORS + 1))
      fi
    fi
  fi

  # Check hooks/ has at least one hook file
  if [ -d "${feature_dir}hooks" ]; then
    hooks_real_files=$(find "${feature_dir}hooks" -maxdepth 1 -type f -not -name ".gitkeep" | wc -l)
    if [ "$hooks_real_files" -gt 0 ]; then
      hook_count=$(find "${feature_dir}hooks" -maxdepth 1 \( -name "use*.ts" -o -name "use*.tsx" \) | wc -l)
      if [ "$hook_count" -eq 0 ]; then
        echo "  FAIL: No hook files (use*.ts) found in hooks/"
        ERRORS=$((ERRORS + 1))
      fi
    fi
  fi

  # Check ui/ has at least one component file (nested subfolders allowed)
  if [ -d "${feature_dir}ui" ]; then
    ui_real_files=$(find "${feature_dir}ui" -type f -not -name ".gitkeep" | wc -l)
    if [ "$ui_real_files" -gt 0 ]; then
      ui_count=$(find "${feature_dir}ui" -name "*.tsx" | wc -l)
      if [ "$ui_count" -eq 0 ]; then
        echo "  FAIL: No component files (*.tsx) found in ui/"
        ERRORS=$((ERRORS + 1))
      fi
    fi
  fi
done

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS structure violation(s) found."
  echo ""
  echo "Each feature MUST have:"
  echo "  api/types.ts        — Raw backend types (mirror backend exactly)"
  echo "  api/<name>Api.ts    — Fetch functions"
  echo "  model/types.ts      — Domain types (YOUR types, YOUR naming)"
  echo "  model/mappers.ts    — Anti-corruption layer (translator)"
  echo "  hooks/use*.ts       — Data-fetching hooks (TanStack Query)"
  echo "  ui/*.tsx             — Presentational components (nested subfolders allowed)"
  echo "  index.ts            — Barrel export (public API)"
  exit 1
else
  echo "PASSED: All feature folders have valid structure."
  exit 0
fi
