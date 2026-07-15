#!/usr/bin/env bash
#
# Validates that each tileserver feature folder has the required 4-layer structure:
#   schemas/__init__.py   — Pydantic API request/response models
#   repository/__init__.py — Local data access (SQLite, filesystem)
#   services/__init__.py  — Business logic (no FastAPI)
#   router/__init__.py    — FastAPI route handlers
#   __init__.py           — Feature package (barrel export)
#
# Usage: ./validate-tileserver-feature-structure.sh <features_dir>
#
set -euo pipefail

FEATURES_DIR="${1:-src/features}"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist yet."
  echo "      This is OK if no features have been created."
  exit 0
fi

REQUIRED_SUBDIRS=("schemas" "repository" "services" "router")
ERRORS=0

echo "=========================================="
echo "  Tileserver Feature Folder Structure"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")
  [ "$feature_name" = "__pycache__" ] && continue

  echo ""
  echo "Feature: $feature_name"

  if [ ! -f "${feature_dir}__init__.py" ]; then
    echo "  FAIL: Missing __init__.py (feature package marker + barrel export)"
    ERRORS=$((ERRORS + 1))
  fi

  for subdir in "${REQUIRED_SUBDIRS[@]}"; do
    if [ ! -d "${feature_dir}${subdir}" ]; then
      echo "  FAIL: Missing required directory: ${subdir}/"
      ERRORS=$((ERRORS + 1))
    fi
  done

  for subdir in "${REQUIRED_SUBDIRS[@]}"; do
    if [ -d "${feature_dir}${subdir}" ]; then
      if [ ! -f "${feature_dir}${subdir}/__init__.py" ]; then
        echo "  FAIL: Missing ${subdir}/__init__.py"
        ERRORS=$((ERRORS + 1))
      fi
    fi
  done
done

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS structure violation(s) found."
  echo ""
  echo "Each tileserver feature MUST have:"
  echo "  __init__.py              — Feature package (barrel export)"
  echo "  schemas/__init__.py      — Pydantic API request/response models"
  echo "  repository/__init__.py   — Local data access (SQLite, filesystem)"
  echo "  services/__init__.py     — Business logic + orchestration"
  echo "  router/__init__.py       — FastAPI route handlers"
  exit 1
else
  echo "PASSED: All tileserver feature folders have valid structure."
  exit 0
fi
