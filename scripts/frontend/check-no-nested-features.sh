#!/usr/bin/env bash
#
# Checks that no feature folder is nested inside another feature folder.
# Features must be direct children of src/features/ — no deeper.
#
# Blocks patterns like:
#   src/features/users/posts/        ← WRONG: nested feature
#   src/features/users/features/     ← WRONG: features inside feature
#   src/features/users/api/hooks/    ← WRONG: layer inside layer
#   src/features/users/components/   ← WRONG: not a valid layer name
#
# Also enforces that layer folders (api/, model/, hooks/) are flat —
# no subdirectories allowed inside them.
# Exception: ui/ allows nested subfolders for component grouping.
#
# Usage: ./check-no-nested-features.sh <features_dir>
#
set -euo pipefail

FEATURES_DIR="${1:-src/features}"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist yet."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Nested Feature Folder Check"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

# Valid layer directories — these are the ONLY subdirectories allowed inside a feature
VALID_LAYERS=("api" "model" "hooks" "ui")

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")
  echo ""
  echo "Feature: $feature_name"

  # Check each subdirectory inside the feature
  for subdir in "$feature_dir"*/; do
    [ -d "$subdir" ] || continue

    subdir_name=$(basename "$subdir")

    # Is this a valid layer?
    is_valid=false
    for valid in "${VALID_LAYERS[@]}"; do
      if [ "$subdir_name" = "$valid" ]; then
        is_valid=true
        break
      fi
    done

    if [ "$is_valid" = false ]; then
      echo "  FAIL: '$feature_name/$subdir_name/' is not a valid layer."
      echo "    Allowed layers: ${VALID_LAYERS[*]}"
      echo "    A feature folder must NOT contain another feature or non-layer folder."
      ERRORS=$((ERRORS + 1))
    fi

    # Check for nested directories inside layer folders
    # Layers (api/, model/, hooks/) must be flat — no subdirectories
    # Exception: __tests__/ is allowed inside any layer for colocated tests
    # Exception: ui/ allows nested subfolders for component grouping
    if [ "$subdir_name" != "ui" ]; then
      nested_dirs=$(find "$subdir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null || true)
      if [ -n "$nested_dirs" ]; then
        invalid_dirs=""
        while IFS= read -r ndir; do
          ndir_name=$(basename "$ndir")
          if [ "$ndir_name" != "__tests__" ]; then
            invalid_dirs="$invalid_dirs$ndir\n"
          fi
        done <<< "$nested_dirs"
        if [ -n "$invalid_dirs" ]; then
          echo "  FAIL: Found nested directories inside '$feature_name/$subdir_name/'"
          echo "    Layers (api/, model/, hooks/) must be flat — no subdirectories."
          echo "    Exception: __tests__/ is allowed for colocated tests."
          echo "    Offending:"
          echo -e "$invalid_dirs" | sed 's/^/      /'
          ERRORS=$((ERRORS + 1))
        fi
      fi
    fi
  done

  # Check for stray files that aren't index.ts at feature root
  for file in "$feature_dir"*; do
    [ -f "$file" ] || continue
    filename=$(basename "$file")
    if [ "$filename" != "index.ts" ]; then
      echo "  FAIL: Stray file '$filename' at feature root."
      echo "    Only index.ts (barrel export) is allowed at feature root level."
      ERRORS=$((ERRORS + 1))
    fi
  done
done

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS nesting violation(s) found."
  echo ""
  echo "Rules:"
  echo "  1. Features must be DIRECT children of src/features/"
  echo "  2. A feature can only contain: api/  model/  hooks/  ui/  index.ts"
  echo "  3. No feature folder inside a feature folder"
  echo "  4. No subdirectories inside layer folders (except __tests__/ and ui/ nesting)"
  echo "  5. No stray files at feature root (only index.ts allowed)"
  exit 1
else
  echo "PASSED: No nested feature folders detected."
  exit 0
fi
