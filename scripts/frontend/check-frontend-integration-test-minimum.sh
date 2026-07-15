#!/usr/bin/env bash
#
# Enforces that each integration test file (*.integration.test.*) in
# ui/__tests__/ contains at least MIN_TESTS (default: 10) test cases.
#
# Test cases are counted by matching lines that start with 'it(' or
# 'test(' (with optional leading whitespace).
#
# Usage: ./check-frontend-integration-test-minimum.sh <features_dir> [min_tests]
#
set -euo pipefail

FEATURES_DIR="${1:-src/features}"
MIN_TESTS="${2:-10}"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist yet."
  echo "      This is OK if no features have been created."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Frontend Integration Test Minimum"
echo "  Directory: $FEATURES_DIR"
echo "  Minimum tests per integration file: $MIN_TESTS"
echo "=========================================="

# Find all integration test files in any ui/__tests__/ directory
integration_files=$(find "$FEATURES_DIR" -type f -name "*.integration.test.*" 2>/dev/null || true)

if [ -z "$integration_files" ]; then
  echo ""
  echo "INFO: No integration test files found."
  echo "PASSED: No integration test files to check."
  exit 0
fi

while IFS= read -r test_file; do
  [ -f "$test_file" ] || continue

  filename=$(basename "$test_file")

  # Count test cases: lines matching it( or test( at start (with optional whitespace)
  test_count=$(grep -cE '^\s*(it|test)\(' "$test_file" 2>/dev/null || true)

  if [ "$test_count" -lt "$MIN_TESTS" ]; then
    echo ""
    echo "FAIL: '$filename' has only $test_count integration tests (minimum: $MIN_TESTS)"
    echo "      Need $((MIN_TESTS - test_count)) more test case(s)."
    ERRORS=$((ERRORS + 1))
  fi
done <<< "$integration_files"

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS integration test file(s) below the $MIN_TESTS test minimum."
  echo ""
  echo "Rule: Each integration test file must have at least"
  echo "      $MIN_TESTS test cases (it() or test() calls)."
  echo ""
  echo "Add more integration test cases covering:"
  echo "  - User interactions (click, type, submit, navigate)"
  echo "  - API success and error scenarios"
  echo "  - Loading and empty states"
  echo "  - Cross-component data flow"
  echo "  - Edge cases (empty data, null responses, network errors)"
  exit 1
else
  echo "PASSED: All integration test files meet the $MIN_TESTS test minimum."
  exit 0
fi
