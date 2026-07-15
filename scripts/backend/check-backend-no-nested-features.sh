#!/usr/bin/env bash
#
# Checks that no backend feature folder is nested inside another feature folder.
# Features must be direct children of src/features/ — no deeper.
#
# Blocks patterns like:
#   src/features/users/posts/         ← WRONG: nested feature
#   src/features/users/features/      ← WRONG: features inside feature
#   src/features/users/clients/helpers/  ← WRONG: subdirectory inside layer
#   src/features/users/controllers/   ← WRONG: not a valid layer name
#
# Also enforces that layer folders are flat — no subdirectories inside them.
#
# Usage: ./check-backend-no-nested-features.sh <features_dir>
#
set -euo pipefail

FEATURES_DIR="${1:-src/features}"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist yet."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Backend Nested Feature Folder Check"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

# Valid layer directories for backend features
VALID_LAYERS=("clients" "models" "services" "router")

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")
  echo ""
  echo "Feature: $feature_name"

  # Check each subdirectory inside the feature
  for subdir in "$feature_dir"*/; do
    [ -d "$subdir" ] || continue

    subdir_name=$(basename "$subdir")

    # __pycache__ is a Python runtime artifact, not a layer or feature folder —
    # ignore it here (it's already excluded from git via .gitignore).
    if [ "$subdir_name" = "__pycache__" ]; then
      continue
    fi

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
    # Layers (clients/, models/, services/, router/) must be flat.
    # __pycache__ is a Python runtime artifact, not a real nested folder — excluded.
    nested_dirs=$(find "$subdir" -mindepth 1 -maxdepth 1 -type d -not -name "__pycache__" 2>/dev/null || true)
    if [ -n "$nested_dirs" ]; then
      echo "  FAIL: Found nested directories inside '$feature_name/$subdir_name/'"
      echo "    Layers must be flat — no subdirectories."
      echo "    Offending:"
      echo "$nested_dirs" | sed 's/^/      /'
      ERRORS=$((ERRORS + 1))
    fi
  done

  # Check for stray .py files at feature root (only __init__.py allowed)
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
  echo "  2. A feature can only contain: clients/  models/  services/  router/  __init__.py"
  echo "  3. No feature folder inside a feature folder"
  echo "  4. No subdirectories inside layer folders (clients/, models/, etc.)"
  echo "  5. No stray .py files at feature root (only __init__.py allowed)"
  exit 1
else
  echo "PASSED: No nested feature folders detected."
  exit 0
fi
