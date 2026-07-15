#!/usr/bin/env bash
#
# Enforces barrel export rules for tileserver features (__init__.py):
#
#   1. __init__.py must only export: schemas, services, router
#   2. __init__.py must NOT export repository functions (internal data access)
#
# Usage: ./check-tileserver-barrel-exports.sh <features_dir>
#
set -euo pipefail

FEATURES_DIR="${1:-src/features}"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist yet."
  exit 0
fi

ERRORS=0
WARNINGS=0

echo "=========================================="
echo "  Tileserver Barrel Export Rules Check"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")
  [ "$feature_name" = "__pycache__" ] && continue

  barrel_file="${feature_dir}__init__.py"

  echo ""
  echo "Feature: $feature_name"

  if [ ! -f "$barrel_file" ]; then
    echo "  FAIL: Missing __init__.py (barrel export)"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # ─── Rule 1: __init__.py must NOT export from repository/ ───
  if grep -qE "from\s+\.repository|from\s+\.\.repository" "$barrel_file" 2>/dev/null; then
    echo "  FAIL: __init__.py exports from repository/ — data access must stay internal"
    echo "    Remove: from .repository import ..."
    echo "    repository/ contains data access — it's an implementation detail."
    ERRORS=$((ERRORS + 1))
  fi

  # Check if this is a scaffolded/empty feature
  is_scaffold=true
  for subdir in schemas repository services router; do
    layer_init="${feature_dir}${subdir}/__init__.py"
    if [ -f "$layer_init" ]; then
      layer_content=$(grep -vE '^\s*#|^\s*$|^"""' "$layer_init" 2>/dev/null || true)
      if [ -n "$layer_content" ]; then
        is_scaffold=false
        break
      fi
    fi
  done

  if [ "$is_scaffold" = true ]; then
    echo "  SKIP: Scaffolded feature (empty layer __init__.py files) — no implementation yet"
    continue
  fi

  # ─── Rule 2: __init__.py should export schemas (advisory) ───
  if ! grep -qE "from\s+\.schemas|from\s+\.\.schemas" "$barrel_file" 2>/dev/null; then
    content=$(grep -vE '^\s*#|^\s*$|^"""' "$barrel_file" 2>/dev/null || true)
    if [ -z "$content" ]; then
      echo "  WARN: __init__.py is empty — consider exporting schemas"
      WARNINGS=$((WARNINGS + 1))
    fi
  fi

  # ─── Rule 3: __init__.py should export router (advisory) ───
  if ! grep -qE "from\s+\.router|from\s+\.\.router" "$barrel_file" 2>/dev/null; then
    content=$(grep -vE '^\s*#|^\s*$|^"""' "$barrel_file" 2>/dev/null || true)
    if [ -z "$content" ]; then
      echo "  WARN: __init__.py does not export router"
      WARNINGS=$((WARNINGS + 1))
    fi
  fi
done

echo ""
echo "=========================================="
if [ "$WARNINGS" -gt 0 ]; then
  echo "NOTE: $WARNINGS advisory warning(s) — not blocking, see above."
fi
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS barrel export violation(s) found."
  echo ""
  echo "Barrel Export Rules (__init__.py):"
  echo "  __init__.py MUST export:"
  echo "    - Schemas from schemas/        (from .schemas import BaseMapResponse)"
  echo "    - Router from router/          (from .router import router)"
  echo "    - Services from services/      (from .services import get_all_basemaps)"
  echo ""
  echo "  __init__.py MUST NOT export:"
  echo "    - repository/ data access functions (internal implementation detail)"
  exit 1
else
  echo "PASSED: All barrel exports are valid."
  exit 0
fi
