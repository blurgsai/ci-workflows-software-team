#!/usr/bin/env bash
#
# Enforces that each file in any hooks/ directory exports at most ONE
# function (hook). If a hook needs helper functions or related hooks,
# they must be in separate files and imported.
#
# Valid:
#   hooks/useFoo.ts        → exports only useFoo
#   hooks/useBar.ts        → exports only useBar
#
# Invalid (will FAIL):
#   hooks/useFoo.ts        → exports useFoo AND useBar
#
# Non-function exports (types, constants, contexts) are allowed alongside
# the single function export.
#
# Usage: ./check-hooks-single-function-per-file.sh <features_dir>
#
set -euo pipefail

FEATURES_DIR="${1:-src/features}"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist yet."
  echo "      This is OK if no features have been created."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Hooks Single-Function-Per-File Validation"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

# Find all hooks/ directories within features, excluding __tests__ subdirs
hooks_dirs=$(find "$FEATURES_DIR" -type d -name "hooks" 2>/dev/null || true)

if [ -z "$hooks_dirs" ]; then
  echo ""
  echo "INFO: No hooks/ directories found."
  echo "PASSED: No hooks directories to check."
  exit 0
fi

while IFS= read -r hooks_dir; do
  # Find all .ts and .tsx files directly in hooks/ (not in __tests__/)
  while IFS= read -r hook_file; do
    [ -f "$hook_file" ] || continue

    filename=$(basename "$hook_file")

    # Count exported function declarations and arrow-function exports
    # Matches:
    #   export function useFoo
    #   export async function useFoo
    #   export const useFoo = (
    #   export const useFoo = async (
    #   export const useFoo = function
    #   export const useFoo = async function
    func_count=$(grep -cE '^export (async )?function |^export const [a-zA-Z_][a-zA-Z0-9_]* = (async )?\(|^export const [a-zA-Z_][a-zA-Z0-9_]* = (async )?function ' "$hook_file" 2>/dev/null || true)

    if [ "$func_count" -gt 1 ]; then
      feature_name=$(basename "$(dirname "$hooks_dir")")
      echo ""
      echo "FAIL: '$feature_name/hooks/$filename' exports $func_count functions"
      echo "      Each hook file must export at most ONE function."
      echo ""
      echo "      Found exported functions:"
      grep -nE '^export (async )?function |^export const [a-zA-Z_][a-zA-Z0-9_]* = (async )?\(|^export const [a-zA-Z_][a-zA-Z0-9_]* = (async )?function ' "$hook_file" | while IFS= read -r line; do
        echo "        - $line"
      done
      echo ""
      echo "      Split each function into its own file and import if needed."
      ERRORS=$((ERRORS + 1))
    fi
  done < <(find "$hooks_dir" -maxdepth 1 -type f \( -name "*.ts" -o -name "*.tsx" \) -not -path "*/__tests__/*")
done <<< "$hooks_dirs"

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS hook file(s) export more than one function."
  echo ""
  echo "Rule: Each file in hooks/ must export at most ONE function."
  echo "      If you need multiple hooks, create separate files:"
  echo "        hooks/useFoo.ts   → exports useFoo"
  echo "        hooks/useBar.ts   → exports useBar"
  echo "      Then import from each file as needed."
  exit 1
else
  echo "PASSED: All hook files export at most one function."
  exit 0
fi
