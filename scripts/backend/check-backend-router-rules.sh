#!/usr/bin/env bash
#
# Enforces router rules from the FastAPI architecture guide:
#
# From §4 Layer 4 Rules:
#   "Routers only import domain models for response_model"
#   "They delegate all logic to the service layer"
#   "They use FastAPI's dependency injection for shared resources"
#
# From §3 Who Knows What:
#   Router knows about FastAPI: Yes
#   Router knows about external schema: No
#   Router knows about domain model: Yes
#
# Checks:
#   1. Router files must use response_model=DomainModel (not raw schemas)
#   2. Router files must NOT use response_model=*ApiSchema or *ApiDto
#   3. Router files must delegate to services (call service functions)
#   4. Router files must NOT contain business logic (no direct client calls)
#   5. Router files must use Depends() for dependency injection
#
# Usage: ./check-backend-router-rules.sh <features_dir>
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
echo "  Backend Router Rules Check"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")
  router_dir="${feature_dir}router"

  [ -d "$router_dir" ] || continue

  echo ""
  echo "Feature: $feature_name"

  # Check if this is a scaffolded/empty feature (router __init__.py has no real content)
  is_scaffold=true
  router_init="${router_dir}/__init__.py"
  if [ -f "$router_init" ]; then
    router_content=$(grep -vE '^\s*#|^\s*$|^"""' "$router_init" 2>/dev/null || true)
    if [ -n "$router_content" ]; then
      is_scaffold=false
    fi
  fi

  # Skip "should" rules for scaffolded features
  if [ "$is_scaffold" = true ]; then
    echo "  SKIP: Scaffolded feature (empty router __init__.py) — no implementation yet"
    continue
  fi

  while IFS= read -r router_file; do
    [ -f "$router_file" ] || continue
    rel_path="${router_file#${feature_dir}}"

    # ─── Rule 1: Router must NOT use response_model with raw schemas ───
    # Matches the guide's illustrative suffix (*ApiSchema/*ApiDto) AND this
    # project's actual convention (plain *Raw* names, e.g. TrajectoryRawRow).
    if grep -qE "response_model.*[A-Z][a-zA-Z]*(Api(Schema|Dto)\b|Raw[A-Z][a-zA-Z]*)" "$router_file" 2>/dev/null; then
      echo "  FAIL: $rel_path uses response_model with raw API schema"
      echo "    Routers must use domain models for response_model, never *ApiSchema/*ApiDto/*Raw*"
      ERRORS=$((ERRORS + 1))
    fi

    # ─── Rule 2: Router should use APIRouter (advisory) ───
    if ! grep -qE "APIRouter|api_router" "$router_file" 2>/dev/null; then
      echo "  WARN: $rel_path does not define an APIRouter"
      echo "    Router files should create: router = APIRouter(prefix=..., tags=[...])"
      WARNINGS=$((WARNINGS + 1))
    fi

    # ─── Rule 3: Router should delegate to services (advisory) ───
    # Check that router imports from services/
    if ! grep -qE "from\s+\.\.services|from\s+.*\.services" "$router_file" 2>/dev/null; then
      # Check if there are any endpoint decorators — if so, they must delegate to services
      if grep -qE "@router\.(get|post|put|patch|delete)" "$router_file" 2>/dev/null; then
        echo "  WARN: $rel_path has endpoints but does not import from services/"
        echo "    Routers must delegate all logic to the service layer."
        echo "    e.g., from ..services import get_all_users"
        WARNINGS=$((WARNINGS + 1))
      fi
    fi

    # ─── Rule 4: Router must NOT call client functions directly ───
    # Look for calls to fetch_* functions (client layer functions)
    if grep -qE "\bfetch_[a-z_]+\s*\(" "$router_file" 2>/dev/null; then
      echo "  FAIL: $rel_path calls fetch_* functions directly"
      echo "    Routers must delegate to services — never call clients directly."
      echo "    Move the call to services/ and call the service function from router."
      ERRORS=$((ERRORS + 1))
    fi

    # ─── Rule 5: Router must NOT call mapper functions directly ───
    if grep -qE "\bmap_[a-z_]+\s*\(" "$router_file" 2>/dev/null; then
      echo "  FAIL: $rel_path calls map_* functions directly"
      echo "    Routers must delegate to services — never call mappers directly."
      echo "    Mappers are called by services, not routers."
      ERRORS=$((ERRORS + 1))
    fi

    # ─── Rule 6: Router should use Depends() for dependency injection (advisory) ───
    if grep -qE "@router\.(get|post|put|patch|delete)" "$router_file" 2>/dev/null; then
      if ! grep -qE "Depends\s*\(" "$router_file" 2>/dev/null; then
        echo "  WARN: $rel_path has endpoints but does not use Depends()"
        echo "    Routers should use FastAPI's DI for shared resources (HTTP client, DB sessions)."
        echo "    e.g., client: httpx.AsyncClient = Depends(get_http_client)"
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
  echo "  1. response_model must use domain models — never *ApiSchema/*ApiDto"
  echo "  2. Router must define APIRouter with prefix and tags"
  echo "  3. Router must import and call service functions — delegate all logic"
  echo "  4. Router must NOT call fetch_* (client functions) directly"
  echo "  5. Router must NOT call map_* (mapper functions) directly"
  echo "  6. Router must use Depends() for dependency injection"
  exit 1
else
  echo "PASSED: All router rules satisfied."
  exit 0
fi
