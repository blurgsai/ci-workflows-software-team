#!/usr/bin/env bash
#
# Checks that no tileserver feature folder is nested inside another feature folder.
# Features must be direct children of src/features/ — no deeper.
#
# Also enforces that layer folders are flat — no subdirectories inside them.
#
# Usage: ./check-tileserver-no-nested-features.sh <features_dir>
#
set -euo pipefail

FEATURES_DIR="${1:-src/features}"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist yet."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Tileserver Nested Feature Folder Check"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

VALID_LAYERS=("schemas" "repository" "services" "router")

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")
  echo ""
  echo "Feature: $feature_name"

  for subdir in "$feature_dir"*/; do
    [ -d "$subdir" ] || continue

    subdir_name=$(basename "$subdir")

    if [ "$subdir_name" = "__pycache__" ]; then
      continue
    fi

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
      ERRORS=$((ERRORS + 1))
    fi

    nested_dirs=$(find "$subdir" -mindepth 1 -maxdepth 1 -type d -not -name "__pycache__" 2>/dev/null || true)
    if [ -n "$nested_dirs" ]; then
      echo "  FAIL: Found nested directories inside '$feature_name/$subdir_name/'"
      echo "    Layers must be flat — no subdirectories."
      ERRORS=$((ERRORS + 1))
    fi
  done

  for file in "$feature_dir"*.py; do
    [ -f "$file" ] || continue
    filename=$(basename "$file")
    if [ "$filename" != "__init__.py" ]; then
      echo "  FAIL: Stray file '$filename' at feature root."
      echo "    Only __init__.py is allowed at feature root level."
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
  echo "  2. A feature can only contain: schemas/  repository/  services/  router/  __init__.py"
  echo "  3. No feature folder inside a feature folder"
  echo "  4. No subdirectories inside layer folders"
  echo "  5. No stray .py files at feature root (only __init__.py allowed)"
  exit 1
else
  echo "PASSED: No nested feature folders detected."
  exit 0
fi
