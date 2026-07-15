#!/usr/bin/env bash
#
# Enforces that no test files (*.test.* or *.spec.*) may live directly
# inside any hooks/ directory. All hook tests MUST be placed in a
# separate __tests__/ subfolder within hooks/.
#
# Valid structure:
#   hooks/
#     useFoo.ts
#     __tests__/
#       useFoo.test.ts
#
# Invalid structure (will FAIL):
#   hooks/
#     useFoo.ts
#     useFoo.test.ts        ← test file directly in hooks/
#
# Usage: ./check-hooks-no-tests-directly.sh <features_dir>
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
echo "  Hooks Test Placement Validation"
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
  # Find test files directly in the hooks/ directory (not in subdirectories)
  test_files=$(find "$hooks_dir" -maxdepth 1 -type f \( -name "*.test.*" -o -name "*.spec.*" \) 2>/dev/null || true)

  if [ -n "$test_files" ]; then
    feature_name=$(basename "$(dirname "$hooks_dir")")
    echo ""
    echo "FAIL: Feature '$feature_name' has test files directly in hooks/"
    echo "      Test files must be placed in hooks/__tests__/ subfolder."
    echo ""
    echo "      Found:"
    while IFS= read -r test_file; do
      echo "        - $(basename "$test_file")"
    done <<< "$test_files"
    echo ""
    echo "      Move them to: ${hooks_dir#$FEATURES_DIR/}/__tests__/"
    ERRORS=$((ERRORS + 1))
  fi
done <<< "$hooks_dirs"

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS hooks directory(ies) contain test files directly."
  echo ""
  echo "Rule: All hook tests MUST live in hooks/__tests__/ subfolder."
  echo "      No test files (*.test.* or *.spec.*) are allowed directly"
  echo "      inside any hooks/ directory."
  echo ""
  echo "Correct structure:"
  echo "  hooks/"
  echo "    useFoo.ts"
  echo "    __tests__/"
  echo "      useFoo.test.ts"
  exit 1
else
  echo "PASSED: No test files found directly in hooks/ directories."
  exit 0
fi
