#!/usr/bin/env bash
#
# Enforces that each test file in hooks/__tests__/ contains at least
# MIN_TESTS (default: 50) test cases.
#
# Test cases are counted by matching lines that start with 'it(' or
# 'test(' (with optional leading whitespace).
#
# Usage: ./check-hooks-test-minimum.sh <features_dir> [min_tests]
#
set -euo pipefail

FEATURES_DIR="${1:-src/features}"
MIN_TESTS="${2:-50}"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist yet."
  echo "      This is OK if no features have been created."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Hooks Test Minimum Count Validation"
echo "  Directory: $FEATURES_DIR"
echo "  Minimum tests per file: $MIN_TESTS"
echo "=========================================="

# Find all __tests__ directories within hooks/
tests_dirs=$(find "$FEATURES_DIR" -type d -path "*/hooks/__tests__" 2>/dev/null || true)

if [ -z "$tests_dirs" ]; then
  echo ""
  echo "INFO: No hooks/__tests__/ directories found."
  echo "PASSED: No test files to check."
  exit 0
fi

while IFS= read -r tests_dir; do
  feature_name=$(basename "$(dirname "$(dirname "$tests_dir")")")

  # Find all test files in __tests__/
  while IFS= read -r test_file; do
    [ -f "$test_file" ] || continue

    filename=$(basename "$test_file")

    # Count test cases: lines matching it( or test( at start (with optional whitespace)
    test_count=$(grep -cE '^\s*(it|test)\(' "$test_file" 2>/dev/null || true)

    if [ "$test_count" -lt "$MIN_TESTS" ]; then
      echo ""
      echo "FAIL: '$feature_name/hooks/__tests__/$filename' has only $test_count tests (minimum: $MIN_TESTS)"
      echo "      Need $((MIN_TESTS - test_count)) more test case(s)."
      ERRORS=$((ERRORS + 1))
    fi
  done < <(find "$tests_dir" -maxdepth 1 -type f \( -name "*.test.*" -o -name "*.spec.*" \))
done <<< "$tests_dirs"

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS test file(s) below the $MIN_TESTS test minimum."
  echo ""
  echo "Rule: Each test file in hooks/__tests__/ must have at least"
  echo "      $MIN_TESTS test cases (it() or test() calls)."
  echo ""
  echo "Add more test cases covering:"
  echo "  - Edge cases (null, undefined, empty inputs)"
  echo "  - Error handling paths"
  echo "  - Loading and success states"
  echo "  - Callback stability"
  echo "  - Different parameter combinations"
  exit 1
else
  echo "PASSED: All hook test files meet the $MIN_TESTS test minimum."
  exit 0
fi
