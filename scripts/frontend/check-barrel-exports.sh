#!/usr/bin/env bash
#
# Enforces barrel export rules from the architecture guide:
#
#   1. index.ts must only export: domain types, hooks, and UI components
#   2. index.ts must NOT export: api/types.ts (raw API types stay internal)
#   3. index.ts must NOT export: model/mappers.ts (mappers stay internal)
#   4. index.ts must NOT export: api/*Api.ts (fetch functions stay internal)
#
# From the guide:
#   // features/users/index.ts — the PUBLIC API
#   export type { User } from "./model/types";        // [YES] domain type
#   export { useUsers, useUser } from "./hooks/useUsers"; // [YES] hooks
#   export { UserCard } from "./ui/UserCard";          // [YES] components
#   // api/types.ts is NOT exported                   // [NO] raw types stay internal
#   // model/mappers.ts is NOT exported               // [NO] mappers stay internal
#
# Usage: ./check-barrel-exports.sh <features_dir>
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
echo "  Barrel Export Rules Check"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")
  barrel_file="${feature_dir}index.ts"

  echo ""
  echo "Feature: $feature_name"

  if [ ! -f "$barrel_file" ]; then
    echo "  FAIL: Missing barrel export file: index.ts"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Check if this is a scaffolded/empty feature (only .gitkeep files)
  real_file_count=$(find "$feature_dir" -type f -not -name ".gitkeep" -not -name "index.ts" | wc -l)
  if [ "$real_file_count" -eq 0 ]; then
    echo "  SKIP: Scaffolded feature (only .gitkeep placeholders) — no implementation yet"
    # Only check that index.ts doesn't export from forbidden paths
    if grep -qE "export.*from\s+['\"]\.\/api" "$barrel_file" 2>/dev/null; then
      echo "  FAIL: index.ts exports from api/ — raw API types and fetch functions must stay internal"
      ERRORS=$((ERRORS + 1))
    fi
    if grep -qE "export.*from\s+['\"]\.\/model/mappers" "$barrel_file" 2>/dev/null; then
      echo "  FAIL: index.ts exports model/mappers.ts — mappers must stay internal"
      ERRORS=$((ERRORS + 1))
    fi
    continue
  fi

  # ─── Rule 1: index.ts must NOT export from api/ ───
  if grep -qE "export.*from\s+['\"]\.\/api" "$barrel_file" 2>/dev/null; then
    echo "  FAIL: index.ts exports from api/ — raw API types and fetch functions must stay internal"
    echo "    Remove: export ... from './api/...'"
    echo "    api/types.ts and api/*Api.ts are internal implementation details."
    ERRORS=$((ERRORS + 1))
  fi

  # ─── Rule 2: index.ts must NOT export mappers.ts ───
  if grep -qE "export.*from\s+['\"]\.\/model/mappers" "$barrel_file" 2>/dev/null; then
    echo "  FAIL: index.ts exports model/mappers.ts — mappers must stay internal"
    echo "    Remove: export ... from './model/mappers'"
    echo "    The mapper is the anti-corruption layer — it's an implementation detail."
    ERRORS=$((ERRORS + 1))
  fi

  # ─── Rule 3: index.ts should export at least one domain type from model/types (advisory) ───
  if ! grep -qE "export.*from\s+['\"]\.\/model/types" "$barrel_file" 2>/dev/null; then
    echo "  WARN: index.ts does not export any domain types from model/types"
    echo "    Consider: export type { ... } from './model/types'"
    WARNINGS=$((WARNINGS + 1))
  fi

  # ─── Rule 4: index.ts should export hooks (advisory — not all features have hooks) ───
  if ! grep -qE "export.*from\s+['\"]\.\/hooks" "$barrel_file" 2>/dev/null; then
    echo "  WARN: index.ts does not export any hooks"
    echo "    Consider: export { use... } from './hooks/use...'"
    WARNINGS=$((WARNINGS + 1))
  fi

  # ─── Rule 5: index.ts should export UI components (advisory — not all features have UI) ───
  if ! grep -qE "export.*from\s+['\"]\.\/ui" "$barrel_file" 2>/dev/null; then
    echo "  WARN: index.ts does not export any UI components"
    echo "    Consider: export { ... } from './ui/...'"
    WARNINGS=$((WARNINGS + 1))
  fi

  # ─── Rule 6: index.ts must NOT export raw API type names ───
  # Matches both the guide's illustrative suffix (*ApiResponse/*ApiSchema/*ApiDto)
  # and this project's actual convention (plain *Api suffix, e.g. VesselConfigApi).
  if grep -qE "export.*[A-Z][a-zA-Z]*Api(Response|Schema|Dto)?\b" "$barrel_file" 2>/dev/null; then
    echo "  FAIL: index.ts exports raw API type — domain types only in barrel"
    echo "    Raw API types (*Api, *ApiResponse, *ApiSchema, *ApiDto) must not be in the public API."
    ERRORS=$((ERRORS + 1))
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
  echo "Barrel Export Rules:"
  echo "  index.ts MUST export:"
  echo "    - Domain types from model/types.ts   (export type { User } from './model/types')"
  echo "    - Hooks from hooks/                  (export { useUsers } from './hooks/useUsers')"
  echo "    - UI components from ui/             (export { UserCard } from './ui/UserCard')"
  echo ""
  echo "  index.ts MUST NOT export:"
  echo "    - api/types.ts                       (raw API types stay internal)"
  echo "    - model/mappers.ts                   (mappers stay internal)"
  echo "    - api/*Api.ts                        (fetch functions stay internal)"
  echo "    - Any *Api, *ApiResponse, *ApiSchema, *ApiDto (raw API type names)"
  exit 1
else
  echo "PASSED: All barrel exports are valid."
  exit 0
fi
