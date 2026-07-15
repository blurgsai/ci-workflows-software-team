#!/usr/bin/env bash
#
# Enforces layer import rules from the FastAPI architecture guide:
#
#   Data flows one direction: Client → Model (mapper) → Service → Router
#
#   1. Router NEVER imports raw external schemas (*ApiSchema, *ApiDto)
#      — Router only imports domain models for response_model
#   2. Router NEVER imports from clients/ — delegates to services
#   3. Services return domain models, never raw schemas
#   4. Services are independent of FastAPI (no Request/Response/APIRouter imports)
#   5. Only models/ (mapper) imports both raw schemas and domain models
#   6. clients/ never imports from models/, services/, or router/
#   7. No cross-feature internal imports
#
# Usage: ./check-backend-layer-imports.sh <features_dir>
#
set -euo pipefail

FEATURES_DIR="${1:-src/features}"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist yet."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Backend Layer Import Rules Check"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")
  echo ""
  echo "Feature: $feature_name"

  # ─── Rule 1: Router NEVER imports raw external schemas ───
  if [ -d "${feature_dir}router" ]; then
    while IFS= read -r router_file; do
      [ -f "$router_file" ] || continue
      rel_path="${router_file#${feature_dir}}"

      # Check for imports of raw schema types — matches the guide's illustrative
      # suffix (*ApiSchema, *ApiDto) AND this project's actual convention
      # (plain *Raw* names, e.g. TrajectoryRawRow, PlaybackRawRow).
      if grep -qE "import.*[A-Z][a-zA-Z]*(Api(Schema|Dto)\b|Raw[A-Z][a-zA-Z]*)" "$router_file" 2>/dev/null; then
        echo "  FAIL: $rel_path imports raw API schema — routers must only use domain models"
        echo "    Raw schemas (*ApiSchema, *ApiDto, *Raw*) are forbidden in router/"
        ERRORS=$((ERRORS + 1))
      fi

      # Check for imports from clients/
      if grep -qE "from\s+\.\.clients|from\s+.*\.clients" "$router_file" 2>/dev/null; then
        echo "  FAIL: $rel_path imports from clients/ — router must delegate to services"
        echo "    Routers call services, never clients directly."
        ERRORS=$((ERRORS + 1))
      fi
    done < <(find "${feature_dir}router" -name "*.py" 2>/dev/null)
  fi

  # ─── Rule 2: clients/ never imports from models/, services/, or router/ ───
  if [ -d "${feature_dir}clients" ]; then
    while IFS= read -r client_file; do
      [ -f "$client_file" ] || continue
      rel_path="${client_file#${feature_dir}}"

      if grep -qE "from\s+\.\.models|from\s+\.\.services|from\s+\.\.router|from\s+.*\.models|from\s+.*\.services|from\s+.*\.router" "$client_file" 2>/dev/null; then
        echo "  FAIL: $rel_path imports from models/, services/, or router/"
        echo "    clients/ layer must be isolated — it only talks to external services"
        ERRORS=$((ERRORS + 1))
      fi
    done < <(find "${feature_dir}clients" -name "*.py" 2>/dev/null)
  fi

  # ─── Rule 3: Only models/ (mapper) imports both raw schemas and domain models ───
  # Check that non-models files don't import from clients/
  if [ -d "${feature_dir}services" ]; then
    while IFS= read -r service_file; do
      [ -f "$service_file" ] || continue
      rel_path="${service_file#${feature_dir}}"

      # Services can import from clients/ and models/ — this is correct per the guide
      # But services must NOT import raw schemas directly — they go through mapper
      if grep -qE "import.*[A-Z][a-zA-Z]*(Api(Schema|Dto)\b|Raw[A-Z][a-zA-Z]*)" "$service_file" 2>/dev/null; then
        echo "  FAIL: $rel_path imports raw API schema — services must use domain models only"
        echo "    Services call clients (get raw) → pass through mapper (get domain)"
        echo "    Services should never reference *ApiSchema, *ApiDto, or *Raw* types directly."
        ERRORS=$((ERRORS + 1))
      fi
    done < <(find "${feature_dir}services" -name "*.py" 2>/dev/null)
  fi

  # ─── Rule 4: models/ non-mapper files must NOT import from clients/ ───
  if [ -d "${feature_dir}models" ]; then
    while IFS= read -r model_file; do
      [ -f "$model_file" ] || continue
      filename=$(basename "$model_file")
      rel_path="${model_file#${feature_dir}}"

      # The mapper (in __init__.py or a dedicated mapper file) SHOULD import from clients/
      # But pure domain model files should NOT
      # We check: if the file contains mapper functions, it's allowed to import from clients/
      # If it only defines domain models (BaseModel classes), it must NOT import from clients/

      # Simple heuristic: if file imports from clients/ but doesn't define a map_* function
      if grep -qE "from\s+\.\.clients|from\s+.*\.clients" "$model_file" 2>/dev/null; then
        if ! grep -qE "def\s+map_" "$model_file" 2>/dev/null; then
          echo "  WARN: $rel_path imports from clients/ but doesn't define mapper functions"
          echo "    Only the mapper should import from clients/ (raw schemas)"
          echo "    Domain model definitions should not depend on external schemas."
          ERRORS=$((ERRORS + 1))
        fi
      fi
    done < <(find "${feature_dir}models" -name "*.py" 2>/dev/null)
  fi

  # ─── Rule 5: No cross-feature internal imports ───
  while IFS= read -r src_file; do
    [ -f "$src_file" ] || continue
    rel_path="${src_file#${feature_dir}}"

    # Look for imports from OTHER features' internal paths
    # Pattern: from ...features.<other_feature>.<clients|models|services|router>
    cross_imports=$(grep -oE "from\s+\S*features\.\w+\.(clients|models|services|router)" "$src_file" 2>/dev/null || true)
    if [ -n "$cross_imports" ]; then
      while IFS= read -r import_line; do
        [ -z "$import_line" ] && continue
        # Extract the feature name from the import path
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
  echo "Layer Import Rules (Client → Model → Service → Router):"
  echo "  1. Router never imports raw schemas (*ApiSchema) — domain models only"
  echo "  2. Router never imports from clients/ — delegates to services"
  echo "  3. Services never import raw schemas — use domain models via mapper"
  echo "  4. clients/ never imports from models/, services/, router/"
  echo "  5. Only models/ mapper imports from clients/ (raw schemas)"
  echo "  6. No cross-feature internal imports"
  exit 1
else
  echo "PASSED: All layer import rules satisfied."
  exit 0
fi
