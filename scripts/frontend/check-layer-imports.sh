#!/usr/bin/env bash
#
# Enforces layer import rules from the architecture guide:
#
#   1. UI components NEVER import from api/ — only from model/types.ts
#   2. UI components never import raw API types (e.g., *ApiResponse, *ApiSchema)
#   3. Hooks import from api/ (fetch) and model/ (mapper) — but NOT from ui/
#   4. Model/mappers.ts is the ONLY file that imports both api types and domain types
#   5. api/ files never import from model/, hooks/, or ui/
#   6. Data flows one direction: API → Model → Hooks → UI
#
# Usage: ./check-layer-imports.sh <features_dir>
#
set -euo pipefail

FEATURES_DIR="${1:-src/features}"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist yet."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Layer Import Rules Check"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")
  echo ""
  echo "Feature: $feature_name"

  # ─── Rule 1: UI components NEVER import from api/ ───
  if [ -d "${feature_dir}ui" ]; then
    while IFS= read -r ui_file; do
      [ -f "$ui_file" ] || continue
      rel_path="${ui_file#${feature_dir}}"

      # Check for imports from api/
      if grep -qE "from\s+['\"]\.\./api|from\s+['\"]\.\./\.\./api|from\s+['\"].*api/types|from\s+['\"].*api/" "$ui_file" 2>/dev/null; then
        echo "  FAIL: $rel_path imports from api/ — UI must NOT know about API layer"
        echo "    UI components can only import from model/types.ts"
        ERRORS=$((ERRORS + 1))
      fi

      # Check for raw API type names — matches the guide's illustrative suffix
      # (*ApiResponse, *ApiSchema, *ApiDto) AND this project's actual convention
      # (plain *Api suffix, e.g. VesselConfigApi, CustomShapeApi).
      if grep -qE "import.*[A-Z][a-zA-Z]*Api(Response|Schema|Dto)?\b" "$ui_file" 2>/dev/null; then
        echo "  FAIL: $rel_path imports raw API type — UI must only use domain types"
        echo "    Raw API types (e.g., *Api, *ApiResponse, *ApiSchema, *ApiDto) are forbidden in ui/"
        ERRORS=$((ERRORS + 1))
      fi

      # Check for imports from hooks/ (UI should not import hooks directly —
      # hooks are exported via barrel, pages consume them)
      if grep -qE "from\s+['\"]\.\./hooks|from\s+['\"]\.\./\.\./hooks" "$ui_file" 2>/dev/null; then
        echo "  WARN: $rel_path imports from hooks/ — UI should be presentational only"
      fi
    done < <(find "${feature_dir}ui" \( -name "*.tsx" -o -name "*.ts" \) 2>/dev/null)
  fi

  # ─── Rule 2: api/ files never import from model/, hooks/, or ui/ ───
  if [ -d "${feature_dir}api" ]; then
    while IFS= read -r api_file; do
      [ -f "$api_file" ] || continue
      rel_path="${api_file#${feature_dir}}"

      if grep -qE "from\s+['\"]\.\./model|from\s+['\"]\.\./hooks|from\s+['\"]\.\./ui" "$api_file" 2>/dev/null; then
        echo "  FAIL: $rel_path imports from model/, hooks/, or ui/"
        echo "    api/ layer must be isolated — it only talks to the backend"
        ERRORS=$((ERRORS + 1))
      fi
    done < <(find "${feature_dir}api" -maxdepth 1 -name "*.ts" 2>/dev/null)
  fi

  # ─── Rule 3: Hooks import from api/ and model/ but NOT from ui/ ───
  if [ -d "${feature_dir}hooks" ]; then
    while IFS= read -r hook_file; do
      [ -f "$hook_file" ] || continue
      rel_path="${hook_file#${feature_dir}}"

      if grep -qE "from\s+['\"]\.\./ui|from\s+['\"]\.\./\.\./ui" "$hook_file" 2>/dev/null; then
        echo "  FAIL: $rel_path imports from ui/ — hooks must not depend on UI"
        echo "    Data flows one direction: API → Model → Hooks → UI (never reverse)"
        ERRORS=$((ERRORS + 1))
      fi
    done < <(find "${feature_dir}hooks" -maxdepth 1 -name "*.ts" 2>/dev/null)
  fi

  # ─── Rule 4: mappers.ts is the ONLY file that imports both api types and domain types ───
  if [ -d "${feature_dir}model" ]; then
    # Check all files in model/ except mappers.ts
    while IFS= read -r model_file; do
      [ -f "$model_file" ] || continue
      filename=$(basename "$model_file")
      rel_path="${model_file#${feature_dir}}"

      if [ "$filename" = "mappers.ts" ]; then
        # mappers.ts SHOULD import from api/ — this is correct
        continue
      fi

      # Non-mapper files in model/ must NOT import from api/
      if grep -qE "from\s+['\"]\.\./api|from\s+['\"].*api/types" "$model_file" 2>/dev/null; then
        echo "  FAIL: $rel_path imports from api/ — only model/mappers.ts may import API types"
        echo "    The mapper is the ONLY file that touches both worlds (API + domain)"
        ERRORS=$((ERRORS + 1))
      fi
    done < <(find "${feature_dir}model" -maxdepth 1 -name "*.ts" 2>/dev/null)
  fi

  # ─── Rule 5: No cross-feature internal imports ───
  # Check all .ts/.tsx files in the feature for imports from other features' internals
  while IFS= read -r src_file; do
    [ -f "$src_file" ] || continue
    rel_path="${src_file#${feature_dir}}"

    # Look for imports that reach into OTHER features' internal paths
    # Pattern: ../../features/<other_feature>/api, /model, /hooks, /ui (not just barrel)
    cross_imports=$(grep -oE "from\s+['\"][^'\"]*features/[^'\"]*/(api|model|hooks|ui)/" "$src_file" 2>/dev/null || true)
    if [ -n "$cross_imports" ]; then
      # Check if the import is to the SAME feature (allowed) or a DIFFERENT feature (blocked)
      while IFS= read -r import_line; do
        [ -z "$import_line" ] && continue
        # Extract the feature name from the import path
        import_feature=$(echo "$import_line" | grep -oE "features/[^/]+/" | sed 's|features/||;s|/||')
        if [ "$import_feature" != "$feature_name" ]; then
          echo "  FAIL: $rel_path imports from another feature's internals ($import_feature)"
          echo "    Cross-feature internal imports are forbidden."
          echo "    Use the barrel export: import { ... } from 'features/$import_feature'"
          ERRORS=$((ERRORS + 1))
        fi
      done <<< "$cross_imports"
    fi
  done < <(find "${feature_dir}" -name "*.ts" -o -name "*.tsx" 2>/dev/null)
done

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS layer import violation(s) found."
  echo ""
  echo "Layer Import Rules:"
  echo "  1. UI never imports from api/ — only from model/types.ts"
  echo "  2. UI never imports raw API types (*ApiResponse, *ApiSchema)"
  echo "  3. api/ never imports from model/, hooks/, or ui/"
  echo "  4. Only model/mappers.ts may import both API types and domain types"
  echo "  5. Hooks never import from ui/ (one-directional flow)"
  echo "  6. No cross-feature internal imports — use barrel exports"
  exit 1
else
  echo "PASSED: All layer import rules satisfied."
  exit 0
fi
