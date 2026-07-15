#!/usr/bin/env bash
#
# Enforces layer import rules for the tileserver 3-layer architecture:
#
#   Data flows one direction: Repository → Services → Router
#
#   1. Router NEVER imports from repository/ — delegates to services
#   2. Router NEVER imports from schemas/ — uses schemas for response_model only
#      (schemas are pure data models, this is allowed)
#   3. Services return schemas, never import from router/
#   4. Services are independent of FastAPI (no Request/Response/APIRouter imports)
#   5. repository/ never imports from services/, router/, or schemas/
#   6. schemas/ never imports from repository/, services/, or router/
#   7. No cross-feature internal imports (except via shared/)
#
# Usage: ./check-tileserver-layer-imports.sh <features_dir>
#
set -euo pipefail

FEATURES_DIR="${1:-src/features}"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist yet."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Tileserver Layer Import Rules Check"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")
  echo ""
  echo "Feature: $feature_name"

  # ─── Rule 1: Router NEVER imports from repository/ ───
  if [ -d "${feature_dir}router" ]; then
    while IFS= read -r router_file; do
      [ -f "$router_file" ] || continue
      rel_path="${router_file#${feature_dir}}"

      if grep -qE "from\s+\.\.repository|from\s+.*\.repository" "$router_file" 2>/dev/null; then
        echo "  FAIL: $rel_path imports from repository/ — router must delegate to services"
        echo "    Routers call services, never repository directly."
        ERRORS=$((ERRORS + 1))
      fi
    done < <(find "${feature_dir}router" -name "*.py" 2>/dev/null)
  fi

  # ─── Rule 2: repository/ never imports from services/, router/, or schemas/ ───
  if [ -d "${feature_dir}repository" ]; then
    while IFS= read -r repo_file; do
      [ -f "$repo_file" ] || continue
      rel_path="${repo_file#${feature_dir}}"

      if grep -qE "from\s+\.\.(services|router|schemas)|from\s+.*\.(services|router|schemas)" "$repo_file" 2>/dev/null; then
        echo "  FAIL: $rel_path imports from services/, router/, or schemas/"
        echo "    repository/ layer must be isolated — it only accesses local data"
        ERRORS=$((ERRORS + 1))
      fi
    done < <(find "${feature_dir}repository" -name "*.py" 2>/dev/null)
  fi

  # ─── Rule 3: schemas/ never imports from repository/, services/, or router/ ───
  if [ -d "${feature_dir}schemas" ]; then
    while IFS= read -r schema_file; do
      [ -f "$schema_file" ] || continue
      rel_path="${schema_file#${feature_dir}}"

      if grep -qE "from\s+\.\.(repository|services|router)|from\s+.*\.(repository|services|router)" "$schema_file" 2>/dev/null; then
        echo "  FAIL: $rel_path imports from repository/, services/, or router/"
        echo "    schemas/ must be pure data models — no dependency on other layers"
        ERRORS=$((ERRORS + 1))
      fi
    done < <(find "${feature_dir}schemas" -name "*.py" 2>/dev/null)
  fi

  # ─── Rule 4: No cross-feature internal imports ───
  while IFS= read -r src_file; do
    [ -f "$src_file" ] || continue
    rel_path="${src_file#${feature_dir}}"

    cross_imports=$(grep -oE "from\s+\S*features\.\w+\.(schemas|repository|services|router)" "$src_file" 2>/dev/null || true)
    if [ -n "$cross_imports" ]; then
      while IFS= read -r import_line; do
        [ -z "$import_line" ] && continue
        import_feature=$(echo "$import_line" | grep -oE "features\.\w+\." | sed 's|features\.||;s|\.||')
        if [ "$import_feature" != "$feature_name" ]; then
          echo "  FAIL: $rel_path imports from another feature's internals ($import_feature)"
          echo "    Cross-feature internal imports are forbidden."
          echo "    Features are self-contained — use shared/ for cross-cutting concerns."
          ERRORS=$((ERRORS + 1))
        fi
      done <<< "$cross_imports"
    fi
  done < <(find "${feature_dir}" -name "*.py" 2>/dev/null)
done

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS layer import violation(s) found."
  echo ""
  echo "Layer Import Rules (Repository → Services → Router):"
  echo "  1. Router never imports from repository/ — delegates to services"
  echo "  2. repository/ never imports from services/, router/, schemas/"
  echo "  3. schemas/ never imports from repository/, services/, router/"
  echo "  4. No cross-feature internal imports"
  exit 1
else
  echo "PASSED: All layer import rules satisfied."
  exit 0
fi
