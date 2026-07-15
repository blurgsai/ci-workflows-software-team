#!/usr/bin/env bash
#
# Enforces that every backend feature with a router/ directory has at least
# one integration-marked test file in tests/.
#
# A test file is considered an integration test if it contains the marker:
#   pytestmark = pytest.mark.integration
# or individual test functions decorated with:
#   @pytest.mark.integration
#
# The script maps test files to features by naming convention:
#   test_<feature>_router.py  →  feature <feature> with router/
#
# Valid:
#   features/vessels/router/        → tests/test_vessels_router.py (has integration marker)
#   features/world_monitor/router/  → tests/test_world_monitor_router.py (has integration marker)
#
# Invalid (will FAIL):
#   features/auth/router/           → no test_auth_router.py in tests/
#   test_auth_router.py             → no @pytest.mark.integration marker found
#
# Usage: ./check-backend-integration-test-coverage.sh <backend_root>
#   backend_root should contain src/features/ and tests/
#
set -euo pipefail

BACKEND_ROOT="${1:-.}"
FEATURES_DIR="${BACKEND_ROOT}/src/features"
TESTS_DIR="${BACKEND_ROOT}/tests"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist."
  echo "      This is OK if no features have been created."
  exit 0
fi

if [ ! -d "$TESTS_DIR" ]; then
  echo "INFO: Tests directory '$TESTS_DIR' does not exist."
  echo "      This is OK if no tests have been written."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Backend Integration Test Coverage"
echo "  Features: $FEATURES_DIR"
echo "  Tests:    $TESTS_DIR"
echo "=========================================="

# Find all features that have a router/ directory
router_features=$(find "$FEATURES_DIR" -type d -name "router" 2>/dev/null || true)

if [ -z "$router_features" ]; then
  echo ""
  echo "INFO: No features with router/ directories found."
  echo "PASSED: No router features to check."
  exit 0
fi

while IFS= read -r router_dir; do
  # Extract feature name: features/<feature>/router/ → <feature>
  feature_dir=$(dirname "$router_dir")
  feature_name=$(basename "$feature_dir")

  # Expected test file: tests/test_<feature>_router.py
  expected_test="${TESTS_DIR}/test_${feature_name}_router.py"

  if [ ! -f "$expected_test" ]; then
    echo ""
    echo "FAIL: '$feature_name/router/' has no corresponding integration test"
    echo "      Expected: tests/test_${feature_name}_router.py"
    echo "      The test file must contain: pytestmark = pytest.mark.integration"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Check if the test file has the integration marker
  if ! grep -qE 'pytestmark\s*=\s*pytest\.mark\.integration|@pytest\.mark\.integration' "$expected_test" 2>/dev/null; then
    echo ""
    echo "FAIL: 'tests/test_${feature_name}_router.py' is missing @pytest.mark.integration"
    echo "      Add 'pytestmark = pytest.mark.integration' at module level"
    echo "      or decorate individual test functions with @pytest.mark.integration"
    ERRORS=$((ERRORS + 1))
  fi
done <<< "$router_features"

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS feature(s) without integration tests."
  echo ""
  echo "Rule: Every feature with a router/ directory must have a corresponding"
  echo "      test file (tests/test_<feature>_router.py) marked with"
  echo "      @pytest.mark.integration"
  echo ""
  echo "Integration tests should cover:"
  echo "  - HTTP endpoint returns correct status codes"
  echo "  - Request validation (query params, body, path params)"
  echo "  - Response schema matches domain model"
  echo "  - Error handling (404, 400, 422, 502)"
  echo "  - Service layer is called with correct arguments"
  exit 1
else
  echo "PASSED: All router features have integration-marked test files."
  exit 0
fi
