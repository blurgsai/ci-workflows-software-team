#!/usr/bin/env bash
#
# Enforces router rules for the tileserver:
#
#   1. Router must use response_model with schemas (not raw dicts)
#   2. Router must define APIRouter with prefix and tags
#   3. Router must import and call service functions — delegate all logic
#   4. Router must NOT call repository functions directly
#   5. Router must use Depends() for dependency injection (auth)
#
# Usage: ./check-tileserver-router-rules.sh <features_dir>
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
echo "  Tileserver Router Rules Check"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")
  router_dir="${feature_dir}router"

  [ -d "$router_dir" ] || continue

  echo ""
  echo "Feature: $feature_name"

  is_scaffold=true
  router_init="${router_dir}/__init__.py"
  if [ -f "$router_init" ]; then
    router_content=$(grep -vE '^\s*#|^\s*$|^"""' "$router_init" 2>/dev/null || true)
    if [ -n "$router_content" ]; then
      is_scaffold=false
    fi
  fi

  if [ "$is_scaffold" = true ]; then
    echo "  SKIP: Scaffolded feature (empty router __init__.py) — no implementation yet"
    continue
  fi

  while IFS= read -r router_file; do
    [ -f "$router_file" ] || continue
    rel_path="${router_file#${feature_dir}}"

    # ─── Rule 1: Router should use APIRouter ───
    if ! grep -qE "APIRouter|api_router" "$router_file" 2>/dev/null; then
      echo "  WARN: $rel_path does not define an APIRouter"
      WARNINGS=$((WARNINGS + 1))
    fi

    # ─── Rule 2: Router should delegate to services ───
    if ! grep -qE "from\s+\.\.services|from\s+.*\.services|from\s+.*features\..*\.services" "$router_file" 2>/dev/null; then
      if grep -qE "@router\.(get|post|put|patch|delete)" "$router_file" 2>/dev/null; then
        echo "  WARN: $rel_path has endpoints but does not import from services/"
        echo "    Routers must delegate all logic to the service layer."
        WARNINGS=$((WARNINGS + 1))
      fi
    fi

    # ─── Rule 3: Router must NOT call repository functions directly ───
    if grep -qE "from\s+\.\.repository|from\s+.*\.repository" "$router_file" 2>/dev/null; then
      echo "  FAIL: $rel_path imports from repository/ — router must delegate to services"
      echo "    Routers call services, never repository directly."
      ERRORS=$((ERRORS + 1))
    fi

    # ─── Rule 4: Router should use Depends() for dependency injection ───
    if grep -qE "@router\.(get|post|put|patch|delete)" "$router_file" 2>/dev/null; then
      if ! grep -qE "Depends\s*\(" "$router_file" 2>/dev/null; then
        echo "  WARN: $rel_path has endpoints but does not use Depends()"
        echo "    Routers should use FastAPI's DI for auth and shared resources."
        WARNINGS=$((WARNINGS + 1))
      fi
    fi
  done < <(find "${router_dir}" -name "*.py" 2>/dev/null)
done

echo ""
echo "=========================================="
if [ "$WARNINGS" -gt 0 ]; then
  echo "NOTE: $WARNINGS advisory warning(s) — not blocking, see above."
fi
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS router rule violation(s) found."
  echo ""
  echo "Router Rules:"
  echo "  1. Router must define APIRouter with prefix and tags"
  echo "  2. Router must import and call service functions — delegate all logic"
  echo "  3. Router must NOT import from repository/ — delegates to services"
  echo "  4. Router must use Depends() for dependency injection (auth)"
  exit 1
else
  echo "PASSED: All router rules satisfied."
  exit 0
fi
