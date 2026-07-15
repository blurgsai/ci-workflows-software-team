#!/usr/bin/env bash
#
# Enforces coding-standards naming conventions for the React/TypeScript frontend.
#
# Checks:
#   1. File names: .tsx = PascalCase, .ts = camelCase, index.ts = barrel
#   2. Hook files: must start with `use` prefix
#   3. API files: must end with `Api.ts` (e.g. authApi.ts, usersApi.ts)
#   4. Exported function names: camelCase
#   5. Exported React component names (.tsx): PascalCase
#   6. Exported hook names: must start with `use`
#   7. Exported interface / type alias names: PascalCase
#   8. Exported constant names: camelCase or UPPER_SNAKE_CASE (no PascalCase)
#   9. No snake_case identifiers in non-API-layer files (variables, functions)
#
# Usage: ./check-frontend-naming-conventions.sh <src_dir>
#
set -euo pipefail

SRC_DIR="${1:-src}"

if [ ! -d "$SRC_DIR" ]; then
  echo "INFO: Source directory '$SRC_DIR' does not exist."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Frontend Naming Convention Check"
echo "  Directory: $SRC_DIR"
echo "=========================================="

# ── Helpers ──────────────────────────────────────────────────────────────

is_pascal_case() {
  # PascalCase: starts with uppercase, no separators, only alphanumerics
  [[ "$1" =~ ^[A-Z][a-zA-Z0-9]*$ ]]
}

is_camel_case() {
  # camelCase: starts with lowercase, no separators, only alphanumerics
  [[ "$1" =~ ^[a-z][a-zA-Z0-9]*$ ]]
}

is_upper_snake_case() {
  # UPPER_SNAKE_CASE: all uppercase, underscores allowed, at least one letter
  [[ "$1" =~ ^[A-Z][A-Z0-9_]*$ ]]
}

is_snake_case() {
  # snake_case: all lowercase, underscores allowed
  [[ "$1" =~ ^[a-z][a-z0-9_]*$ ]]
}

# ── Check 1: File naming conventions ─────────────────────────────────────
echo ""
echo "── Check 1: File naming conventions ──"

while IFS= read -r filepath; do
  [ -f "$filepath" ] || continue
  filename=$(basename "$filepath")
  stem="${filename%.*}"
  ext="${filename##*.}"

  # Skip index files (barrel exports)
  if [ "$stem" = "index" ]; then
    continue
  fi

  # Skip Vite entry point
  if [ "$filename" = "main.tsx" ]; then
    continue
  fi

  # Skip test files — test files follow the same convention as the file they test
  # (e.g. useFoo.test.ts is camelCase, UserCard.test.tsx is PascalCase)
  if [[ "$filename" == *.test.* ]] || [[ "$filename" == *.spec.* ]]; then
    # Strip .test.* or .spec.* and any .integration suffix to get the real stem
    stem="${filename%.test.*}"
    stem="${stem%.spec.*}"
    stem="${stem%.integration}"
  fi

  # Skip vite-env.d.ts and similar declaration files
  if [[ "$filename" == *.d.ts ]]; then
    continue
  fi

  # .tsx files must be PascalCase (unless they are test files for hooks)
  if [ "$ext" = "tsx" ]; then
    is_test=false
    if [[ "$filename" == *.test.* ]] || [[ "$filename" == *.spec.* ]]; then
      is_test=true
    fi
    if [ "$is_test" = true ] && [[ "$stem" == use* ]]; then
      # Hook test files are camelCase — skip PascalCase check
      :
    elif ! is_pascal_case "$stem"; then
      echo "  FAIL: '$filepath' — .tsx files must use PascalCase naming"
      echo "        Expected: PascalCase (e.g. UserCard.tsx), got: '$stem'"
      ERRORS=$((ERRORS + 1))
    fi
  fi

  # .ts files must be camelCase (exception: *Context and *Provider files use PascalCase)
  if [ "$ext" = "ts" ]; then
    if [[ "$stem" == *Context ]] || [[ "$stem" == *Provider ]]; then
      # Context/Provider files use PascalCase — skip camelCase check
      :
    elif ! is_camel_case "$stem"; then
      echo "  FAIL: '$filepath' — .ts files must use camelCase naming"
      echo "        Expected: camelCase (e.g. authApi.ts), got: '$stem'"
      ERRORS=$((ERRORS + 1))
    fi
  fi
done < <(find "$SRC_DIR" -type f \( -name "*.ts" -o -name "*.tsx" \) \
  -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/build/*" 2>/dev/null || true)

# ── Check 2: Hook files must start with `use` ────────────────────────────
echo ""
echo "── Check 2: Hook files must start with 'use' prefix ──"

while IFS= read -r hook_file; do
  [ -f "$hook_file" ] || continue
  filename=$(basename "$hook_file")
  stem="${filename%.*}"

  # Skip test files and index files
  [[ "$filename" == *.test.* ]] || [[ "$filename" == *.spec.* ]] && continue
  [ "$stem" = "index" ] && continue

  # Skip context/provider files (e.g. AuthContext.ts, AuthProvider.tsx)
  [[ "$stem" == *Context ]] || [[ "$stem" == *Provider ]] && continue

  if [[ "$stem" != use* ]]; then
    echo "  FAIL: '$hook_file' — files in hooks/ must start with 'use' prefix"
    echo "        Expected: useSomething.ts, got: '$filename'"
    ERRORS=$((ERRORS + 1))
  fi
done < <(find "$SRC_DIR" -type d -name "hooks" 2>/dev/null | while IFS= read -r hooks_dir; do
  find "$hooks_dir" -maxdepth 1 -type f \( -name "*.ts" -o -name "*.tsx" \) -not -path "*/__tests__/*"
done || true)

# ── Check 3: API files must end with `Api.ts` ────────────────────────────
echo ""
echo "── Check 3: API files must end with 'Api' suffix ──"

while IFS= read -r api_file; do
  [ -f "$api_file" ] || continue
  filename=$(basename "$api_file")
  stem="${filename%.*}"

  # Skip types.ts, index.ts, and test files
  [ "$stem" = "types" ] && continue
  [ "$stem" = "index" ] && continue
  [[ "$filename" == *.test.* ]] || [[ "$filename" == *.spec.* ]] && continue

  # Skip shared/ directory — shared API utilities (client.ts, etc.) don't need Api suffix
  filepath_dir=$(dirname "$api_file")
  if [[ "$filepath_dir" == */shared/* ]]; then
    continue
  fi

  if [[ "$stem" != *Api ]]; then
    echo "  FAIL: '$api_file' — non-types files in api/ must end with 'Api' suffix"
    echo "        Expected: featureApi.ts (e.g. authApi.ts), got: '$filename'"
    ERRORS=$((ERRORS + 1))
  fi
done < <(find "$SRC_DIR" -type d -name "api" 2>/dev/null | while IFS= read -r api_dir; do
  find "$api_dir" -maxdepth 1 -type f -name "*.ts" -not -path "*/__tests__/*"
done || true)

# ── Check 4: Exported function names must be camelCase ───────────────────
echo ""
echo "── Check 4: Exported function names must be camelCase ──"

while IFS= read -r ts_file; do
  [ -f "$ts_file" ] || continue

  # Extract exported function names
  # Matches: export function fooBar, export async function fooBar
  while IFS= read -r func_name; do
    [ -z "$func_name" ] && continue
    # Skip Context/Provider exports — they use PascalCase by convention
    if [[ "$func_name" == *Context ]] || [[ "$func_name" == *Provider ]]; then
      continue
    fi
    if ! is_camel_case "$func_name"; then
      echo "  FAIL: '$ts_file' — exported function '$func_name' must be camelCase"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(grep -oE '^export (async )?function [a-zA-Z_][a-zA-Z0-9_]*' "$ts_file" 2>/dev/null | sed -E 's/^export (async )?function //' || true)
done < <(find "$SRC_DIR" -type f -name "*.ts" -not -path "*/node_modules/*" -not -path "*/__tests__/*" 2>/dev/null || true)

# ── Check 5: Exported React component names must be PascalCase ───────────
echo ""
echo "── Check 5: Exported React component names must be PascalCase (.tsx) ──"

while IFS= read -r tsx_file; do
  [ -f "$tsx_file" ] || continue

  # Extract exported function/const names from .tsx files
  # Matches: export function FooBar, export const FooBar = (
  while IFS= read -r comp_name; do
    [ -z "$comp_name" ] && continue
    # Skip hooks exported from .tsx (they start with 'use')
    if [[ "$comp_name" == use* ]]; then
      continue
    fi
    # Accept PascalCase (React components) and camelCase (utility functions that return JSX)
    # Only flag names that are neither (e.g. snake_case)
    if ! is_pascal_case "$comp_name" && ! is_camel_case "$comp_name"; then
      echo "  FAIL: '$tsx_file' — exported name '$comp_name' must be PascalCase (component) or camelCase (utility)"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(grep -oE '^export (async )?function [a-zA-Z_][a-zA-Z0-9_]*' "$tsx_file" 2>/dev/null | sed -E 's/^export (async )?function //' || true)
done < <(find "$SRC_DIR" -type f -name "*.tsx" -not -path "*/node_modules/*" -not -path "*/__tests__/*" 2>/dev/null || true)

# ── Check 6: Exported hook names must start with `use` ───────────────────
echo ""
echo "── Check 6: Exported hook names must start with 'use' ──"

while IFS= read -r hook_file; do
  [ -f "$hook_file" ] || continue

  # Extract exported function names
  while IFS= read -r func_name; do
    [ -z "$func_name" ] && continue
    if [[ "$func_name" != use* ]]; then
      echo "  FAIL: '$hook_file' — exported hook '$func_name' must start with 'use' prefix"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(grep -oE '^export (async )?function [a-zA-Z_][a-zA-Z0-9_]*' "$hook_file" 2>/dev/null | sed -E 's/^export (async )?function //' || true)

  # Also check arrow-function exports: export const useFoo = (
  while IFS= read -r const_name; do
    [ -z "$const_name" ] && continue
    if [[ "$const_name" != use* ]] && [[ "$const_name" != *Context ]] && [[ "$const_name" != *Provider ]]; then
      echo "  FAIL: '$hook_file' — exported hook '$const_name' must start with 'use' prefix"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(grep -oE '^export const [a-zA-Z_][a-zA-Z0-9_]* = (async )?\(' "$hook_file" 2>/dev/null | sed -E 's/^export const //; s/ = (async )?\(//' || true)
done < <(find "$SRC_DIR" -type d -name "hooks" 2>/dev/null | while IFS= read -r hooks_dir; do
  find "$hooks_dir" -maxdepth 1 -type f \( -name "*.ts" -o -name "*.tsx" \) -not -path "*/__tests__/*"
done || true)

# ── Check 7: Exported interface / type names must be PascalCase ──────────
echo ""
echo "── Check 7: Exported interface and type alias names must be PascalCase ──"

while IFS= read -r ts_file; do
  [ -f "$ts_file" ] || continue

  # export interface FooBar
  while IFS= read -r iface_name; do
    [ -z "$iface_name" ] && continue
    if ! is_pascal_case "$iface_name"; then
      echo "  FAIL: '$ts_file' — exported interface '$iface_name' must be PascalCase"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(grep -oE '^export interface [a-zA-Z_][a-zA-Z0-9_]*' "$ts_file" 2>/dev/null | sed 's/^export interface //' || true)

  # export type FooBar = ...
  while IFS= read -r type_name; do
    [ -z "$type_name" ] && continue
    if ! is_pascal_case "$type_name"; then
      echo "  FAIL: '$ts_file' — exported type '$type_name' must be PascalCase"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(grep -oE '^export type [a-zA-Z_][a-zA-Z0-9_]*' "$ts_file" 2>/dev/null | sed 's/^export type //' || true)
done < <(find "$SRC_DIR" -type f \( -name "*.ts" -o -name "*.tsx" \) -not -path "*/node_modules/*" -not -path "*/__tests__/*" 2>/dev/null || true)

# ── Check 8: Exported constant names — camelCase or UPPER_SNAKE_CASE ─────
echo ""
echo "── Check 8: Exported constant names must be camelCase or UPPER_SNAKE_CASE ──"

while IFS= read -r ts_file; do
  [ -f "$ts_file" ] || continue
  filename=$(basename "$ts_file")

  # Skip .tsx files (components are handled above)
  [[ "$filename" == *.tsx ]] && continue

  # export const fooBar = ... (not a function, not an arrow function)
  # Match: export const FOO_BAR = 42, export const fooBar = 42
  while IFS= read -r const_name; do
    [ -z "$const_name" ] && continue

    # Skip if it's an arrow function (handled by hook/component checks)
    line=$(grep -E "^export const ${const_name} = (async )?\(" "$ts_file" 2>/dev/null || true)
    if [ -n "$line" ]; then
      continue
    fi

    # Skip Context/Provider constants — they use PascalCase by React convention
    if [[ "$const_name" == *Context ]] || [[ "$const_name" == *Provider ]]; then
      continue
    fi

    if ! is_camel_case "$const_name" && ! is_upper_snake_case "$const_name"; then
      echo "  FAIL: '$ts_file' — exported constant '$const_name' must be camelCase or UPPER_SNAKE_CASE"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(grep -oE '^export const [a-zA-Z_][a-zA-Z0-9_]*' "$ts_file" 2>/dev/null | sed 's/^export const //' || true)
done < <(find "$SRC_DIR" -type f -name "*.ts" -not -path "*/node_modules/*" -not -path "*/__tests__/*" 2>/dev/null || true)

# ── Check 9: No snake_case identifiers in non-API-layer files ─────────────
echo ""
echo "── Check 9: No snake_case variables/functions in non-API-layer files ──"

# Only check model/ and hooks/ layers — API layer mirrors backend (snake_case OK)
# Also skip ui/ since component props might mirror API shapes in edge cases
# Focus on model/types.ts and hooks/ where domain types live

while IFS= read -r model_file; do
  [ -f "$model_file" ] || continue
  filename=$(basename "$model_file")

  # Skip test files
  [[ "$filename" == *.test.* ]] || [[ "$filename" == *.spec.* ]] && continue

  # Check for snake_case property names ONLY inside interface/type definitions
  # Uses awk to track whether we're inside an interface or type block
  # This avoids false positives from object literals in function bodies (e.g. mappers)
  while IFS= read -r line; do
    # Extract the property name
    prop=$(echo "$line" | sed -nE 's/^\s+([a-zA-Z_][a-zA-Z0-9_]*)[?]?:.*/\1/p')
    [ -z "$prop" ] && continue

    # Skip if it's a valid camelCase or single word
    if is_camel_case "$prop" || is_upper_snake_case "$prop"; then
      continue
    fi

    # If it contains underscore and is lowercase, it's snake_case
    if [[ "$prop" == *_* ]] && is_snake_case "$prop"; then
      echo "  FAIL: '$model_file' — snake_case property '$prop' in domain model"
      echo "        Domain types should use camelCase (e.g. userId, not user_id)"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(awk '
    /^export (interface|type) / { in_block = 1; depth = 0 }
    in_block && /{/ { depth++ }
    in_block && /}/ { depth--; if (depth == 0) in_block = 0 }
    in_block && depth > 0 && /^\s+[a-zA-Z_][a-zA-Z0-9_]*[?]?:/ { print }
  ' "$model_file" 2>/dev/null || true)
done < <(find "$SRC_DIR" -type d -name "model" 2>/dev/null | while IFS= read -r model_dir; do
  find "$model_dir" -maxdepth 1 -type f -name "*.ts" -not -path "*/__tests__/*"
done || true)

# ── Summary ──────────────────────────────────────────────────────────────
echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS naming convention violation(s) found."
  echo ""
  echo "Naming Convention Rules:"
  echo "  1. .tsx files: PascalCase (e.g. UserCard.tsx, LoginPage.tsx)"
  echo "  2. .ts files: camelCase (e.g. authApi.ts, mappers.ts)"
  echo "  3. Hook files: must start with 'use' (e.g. useAuth.ts)"
  echo "  4. API files: must end with 'Api' (e.g. authApi.ts)"
  echo "  5. Exported functions: camelCase (e.g. fetchUsers, loginUser)"
  echo "  6. Exported components: PascalCase (e.g. UserCard, LoginPage)"
  echo "  7. Exported hooks: must start with 'use' (e.g. useAuth, useUsers)"
  echo "  8. Exported interfaces/types: PascalCase (e.g. UserApiResponse)"
  echo "  9. Exported constants: camelCase or UPPER_SNAKE_CASE"
  echo " 10. Domain model properties: camelCase (no snake_case)"
  exit 1
else
  echo "PASSED: All naming conventions are correct."
  exit 0
fi
