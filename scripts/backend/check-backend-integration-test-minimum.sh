#!/usr/bin/env bash
#
# Enforces that each integration-marked test file in tests/ contains at least
# MIN_TESTS (default: 5) test functions.
#
# A test file is considered an integration test if it contains:
#   pytestmark = pytest.mark.integration
#
# Test functions are counted by matching lines containing 'def test_'
# (the standard pytest test function naming convention).
#
# Usage: ./check-backend-integration-test-minimum.sh <backend_root> [min_tests]
#
set -euo pipefail

BACKEND_ROOT="${1:-.}"
TESTS_DIR="${BACKEND_ROOT}/tests"
MIN_TESTS="${2:-5}"

if [ ! -d "$TESTS_DIR" ]; then
  echo "INFO: Tests directory '$TESTS_DIR' does not exist."
  echo "      This is OK if no tests have been written."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Backend Integration Test Minimum"
echo "  Directory: $TESTS_DIR"
echo "  Minimum test functions per integration file: $MIN_TESTS"
echo "=========================================="

# Find all test files that have the integration marker
integration_files=""
while IFS= read -r test_file; do
  [ -f "$test_file" ] || continue
  if grep -qE 'pytestmark\s*=\s*pytest\.mark\.integration|@pytest\.mark\.integration' "$test_file" 2>/dev/null; then
    integration_files="$integration_files$test_file"$'\n'
  fi
done < <(find "$TESTS_DIR" -maxdepth 1 -type f -name "test_*.py" 2>/dev/null || true)

if [ -z "$integration_files" ]; then
  echo ""
  echo "INFO: No integration-marked test files found."
  echo "PASSED: No integration test files to check."
  exit 0
fi

while IFS= read -r test_file; do
  [ -f "$test_file" ] || continue

  filename=$(basename "$test_file")

  # Count test functions: lines matching 'def test_'
  test_count=$(grep -cE '^\s*def test_' "$test_file" 2>/dev/null || true)

  if [ "$test_count" -lt "$MIN_TESTS" ]; then
    echo ""
    echo "FAIL: '$filename' has only $test_count integration test functions (minimum: $MIN_TESTS)"
    echo "      Need $((MIN_TESTS - test_count)) more test function(s)."
    ERRORS=$((ERRORS + 1))
  fi
done <<< "$integration_files"

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS integration test file(s) below the $MIN_TESTS test minimum."
  echo ""
  echo "Rule: Each integration-marked test file must have at least"
  echo "      $MIN_TESTS test functions (def test_*)."
  echo ""
  echo "Add more integration test functions covering:"
  echo "  - HTTP endpoint returns correct status codes"
  echo "  - Request validation (query params, body, path params)"
  echo "  - Response schema matches domain model"
  echo "  - Error handling (404, 400, 422, 502)"
  echo "  - Service layer is called with correct arguments"
  exit 1
else
  echo "PASSED: All integration test files meet the $MIN_TESTS test minimum."
  exit 0
fi
