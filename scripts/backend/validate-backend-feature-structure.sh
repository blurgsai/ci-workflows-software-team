#!/usr/bin/env bash
#
# Validates that each backend feature folder has the required 4-layer structure:
#   clients/__init__.py   — External API client + raw schemas
#   models/__init__.py    — Domain models + mappers (anti-corruption layer)
#   services/__init__.py  — Business logic
#   router/__init__.py    — FastAPI route handlers
#   __init__.py           — Feature package (barrel export)
#
# Usage: ./validate-backend-feature-structure.sh <features_dir>
#
set -euo pipefail

FEATURES_DIR="${1:-src/features}"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist yet."
  echo "      This is OK if no features have been created."
  exit 0
fi

REQUIRED_SUBDIRS=("clients" "models" "services" "router")
ERRORS=0

echo "=========================================="
echo "  Backend Feature Folder Structure"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")

  # __pycache__ is a Python runtime artifact, not a feature — skip it.
  [ "$feature_name" = "__pycache__" ] && continue

  echo ""
  echo "Feature: $feature_name"

  # Check for feature-level __init__.py (package marker + barrel export)
  if [ ! -f "${feature_dir}__init__.py" ]; then
    echo "  FAIL: Missing __init__.py (feature package marker + barrel export)"
    ERRORS=$((ERRORS + 1))
  fi

  # Check for required subdirectories
  for subdir in "${REQUIRED_SUBDIRS[@]}"; do
    if [ ! -d "${feature_dir}${subdir}" ]; then
      echo "  FAIL: Missing required directory: ${subdir}/"
      ERRORS=$((ERRORS + 1))
    fi
  done

  # Check clients/ has __init__.py (raw schemas + fetch functions)
  if [ -d "${feature_dir}clients" ]; then
    if [ ! -f "${feature_dir}clients/__init__.py" ]; then
      echo "  FAIL: Missing clients/__init__.py (raw schemas + fetch functions)"
      ERRORS=$((ERRORS + 1))
    fi
  fi

  # Check models/ has __init__.py (domain models + mappers)
  if [ -d "${feature_dir}models" ]; then
    if [ ! -f "${feature_dir}models/__init__.py" ]; then
      echo "  FAIL: Missing models/__init__.py (domain models + mappers)"
      ERRORS=$((ERRORS + 1))
    fi
  fi

  # Check services/ has __init__.py (business logic)
  if [ -d "${feature_dir}services" ]; then
    if [ ! -f "${feature_dir}services/__init__.py" ]; then
      echo "  FAIL: Missing services/__init__.py (business logic + orchestration)"
      ERRORS=$((ERRORS + 1))
    fi
  fi

  # Check router/ has __init__.py (FastAPI route handlers)
  if [ -d "${feature_dir}router" ]; then
    if [ ! -f "${feature_dir}router/__init__.py" ]; then
      echo "  FAIL: Missing router/__init__.py (FastAPI route handlers)"
      ERRORS=$((ERRORS + 1))
    fi
  fi
done

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS structure violation(s) found."
  echo ""
  echo "Each backend feature MUST have:"
  echo "  __init__.py            — Feature package (barrel export)"
  echo "  clients/__init__.py    — External API client + raw schemas"
  echo "  models/__init__.py     — Domain models + mappers (anti-corruption layer)"
  echo "  services/__init__.py   — Business logic + orchestration"
  echo "  router/__init__.py     — FastAPI route handlers"
  exit 1
else
  echo "PASSED: All backend feature folders have valid structure."
  exit 0
fi
