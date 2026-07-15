#!/usr/bin/env bash
#
# Enforces barrel export rules for backend features (__init__.py):
#
#   1. __init__.py must only export: domain models, services, router
#   2. __init__.py must NOT export raw schemas (*ApiSchema, *ApiDto) from clients/
#   3. __init__.py must NOT export mapper functions from models/
#   4. __init__.py must NOT export client fetch functions from clients/
#
# From the guide:
#   Feature boundary = Python package __init__.py
#   clients/ raw schemas are internal — NOT exported
#   models/ mappers are internal — NOT exported
#   Only domain models, services, and router are public API
#
# Usage: ./check-backend-barrel-exports.sh <features_dir>
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
echo "  Backend Barrel Export Rules Check"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")

  # __pycache__ is a Python runtime artifact, not a feature — skip it.
  [ "$feature_name" = "__pycache__" ] && continue

  barrel_file="${feature_dir}__init__.py"

  echo ""
  echo "Feature: $feature_name"

  if [ ! -f "$barrel_file" ]; then
    echo "  FAIL: Missing __init__.py (barrel export)"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Check if this is a scaffolded/empty feature (layer __init__.py files have no real content)
  is_scaffold=true
  for subdir in clients models services router; do
    layer_init="${feature_dir}${subdir}/__init__.py"
    if [ -f "$layer_init" ]; then
      layer_content=$(grep -vE '^\s*#|^\s*$|^"""' "$layer_init" 2>/dev/null || true)
      if [ -n "$layer_content" ]; then
        is_scaffold=false
        break
      fi
    fi
  done

  # ─── Rule 1: __init__.py must NOT export from clients/ ───
  if grep -qE "from\s+\.clients|from\s+\.\.clients" "$barrel_file" 2>/dev/null; then
    echo "  FAIL: __init__.py exports from clients/ — raw schemas and fetch functions must stay internal"
    echo "    Remove: from .clients import ..."
    echo "    clients/ contains external API schemas — they are implementation details."
    ERRORS=$((ERRORS + 1))
  fi

  # ─── Rule 2: __init__.py must NOT export mapper functions ───
  if grep -qE "from\s+\.models.*import.*map_|from\s+\.models.*import.*mapper" "$barrel_file" 2>/dev/null; then
    echo "  FAIL: __init__.py exports mapper functions — mappers must stay internal"
    echo "    Remove: from .models import map_..."
    echo "    The mapper is the anti-corruption layer — it's an implementation detail."
    ERRORS=$((ERRORS + 1))
  fi

  # ─── Rule 3: __init__.py must NOT export raw schema names ───
  # Matches the guide's illustrative suffix (*ApiSchema/*ApiDto) AND this
  # project's actual convention (plain *Raw* names, e.g. TrajectoryRawRow).
  if grep -qE "import.*[A-Z][a-zA-Z]*(Api(Schema|Dto)\b|Raw[A-Z][a-zA-Z]*)" "$barrel_file" 2>/dev/null; then
    echo "  FAIL: __init__.py exports raw API schema — domain models only in barrel"
    echo "    Raw schemas (*ApiSchema, *ApiDto, *Raw*) must not be in the public API."
    ERRORS=$((ERRORS + 1))
  fi

  # Skip "should export" rules for scaffolded features
  if [ "$is_scaffold" = true ]; then
    echo "  SKIP: Scaffolded feature (empty layer __init__.py files) — no implementation yet"
    continue
  fi

  # ─── Rule 4: __init__.py should export domain models (advisory) ───
  if ! grep -qE "from\s+\.models|from\s+\.\.models" "$barrel_file" 2>/dev/null; then
    # Check if it's empty or just a package marker
    content=$(grep -vE '^\s*#|^\s*$|^"""' "$barrel_file" 2>/dev/null || true)
    if [ -z "$content" ]; then
      echo "  WARN: __init__.py is empty — consider exporting domain models"
      echo "    e.g., from .models import User"
      WARNINGS=$((WARNINGS + 1))
    fi
  fi

  # ─── Rule 5: __init__.py should export router (advisory) ───
  if ! grep -qE "from\s+\.router|from\s+\.\.router" "$barrel_file" 2>/dev/null; then
    content=$(grep -vE '^\s*#|^\s*$|^"""' "$barrel_file" 2>/dev/null || true)
    if [ -z "$content" ]; then
      echo "  WARN: __init__.py does not export router"
      echo "    e.g., from .router import router"
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
  echo "    - Domain models from models/     (from .models import User)"
  echo "    - Router from router/            (from .router import router)"
  echo "    - Services from services/        (from .services import get_all_users)"
  echo ""
  echo "  __init__.py MUST NOT export:"
  echo "    - clients/ raw schemas           (*ApiSchema, *ApiDto)"
  echo "    - clients/ fetch functions       (fetch_users, etc.)"
  echo "    - models/ mapper functions       (map_user_from_api, etc.)"
  exit 1
else
  echo "PASSED: All barrel exports are valid."
  exit 0
fi
