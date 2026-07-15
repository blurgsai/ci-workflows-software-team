#!/usr/bin/env bash
#
# Enforces that every hook file (use*.ts or use*.tsx) in any hooks/
# directory has a corresponding test file in hooks/__tests__/.
#
# Valid:
#   hooks/useFoo.ts           → hooks/__tests__/useFoo.test.ts (or .tsx)
#   hooks/useBar.tsx           → hooks/__tests__/useBar.test.tsx (or .ts)
#
# Invalid (will FAIL):
#   hooks/useFoo.ts            → no test file in __tests__/
#
# Non-hook files (AuthContext.ts, AuthProvider.tsx, etc.) are NOT
# required to have test files — only files matching use*.ts/use*.tsx.
#
# Usage: ./check-hooks-test-coverage.sh <features_dir>
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
echo "  Hooks Test Coverage Validation"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

# Find all hooks/ directories within features
hooks_dirs=$(find "$FEATURES_DIR" -type d -name "hooks" 2>/dev/null || true)

if [ -z "$hooks_dirs" ]; then
  echo ""
  echo "INFO: No hooks/ directories found."
  echo "PASSED: No hooks directories to check."
  exit 0
fi

while IFS= read -r hooks_dir; do
  # Find all hook files (use*.ts or use*.tsx) directly in hooks/
  while IFS= read -r hook_file; do
    [ -f "$hook_file" ] || continue

    filename=$(basename "$hook_file")
    base_name="${filename%.*}"  # e.g., useFoo

    feature_name=$(basename "$(dirname "$hooks_dir")")

    # Check for corresponding test file in __tests__/
    tests_dir="${hooks_dir}/__tests__"
    test_found=0

    if [ -d "$tests_dir" ]; then
      # Check for any test file matching the hook name
      for test_file in "${tests_dir}/${base_name}.test.ts" "${tests_dir}/${base_name}.test.tsx" "${tests_dir}/${base_name}.spec.ts" "${tests_dir}/${base_name}.spec.tsx"; do
        if [ -f "$test_file" ]; then
          test_found=1
          break
        fi
      done
    fi

    if [ "$test_found" -eq 0 ]; then
      echo ""
      echo "FAIL: '$feature_name/hooks/$filename' has no corresponding test file"
      echo "      Expected: hooks/__tests__/${base_name}.test.ts (or .tsx)"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(find "$hooks_dir" -maxdepth 1 -type f \( -name "use*.ts" -o -name "use*.tsx" \))
done <<< "$hooks_dirs"

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS hook(s) without a test file."
  echo ""
  echo "Rule: Every hook file (use*.ts/use*.tsx) must have a corresponding"
  echo "      test file in hooks/__tests__/."
  echo ""
  echo "Example:"
  echo "  hooks/useFoo.ts                → hook implementation"
  echo "  hooks/__tests__/useFoo.test.ts  → test file (required)"
  exit 1
else
  echo "PASSED: All hooks have corresponding test files."
  exit 0
fi
