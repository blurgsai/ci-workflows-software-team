#!/usr/bin/env bash
#
# Enforces that every feature with a ui/ directory has at least one
# integration test file (*.integration.test.tsx) in ui/__tests__/.
#
# Valid:
#   features/chatbot/ui/__tests__/ChatBot.integration.test.tsx
#   features/worldMonitoring/ui/__tests__/Articles.integration.test.tsx
#
# Invalid (will FAIL):
#   features/auth/ui/               → no ui/__tests__/ directory
#   features/auth/ui/__tests__/     → no *.integration.test.* file
#
# Usage: ./check-frontend-integration-test-coverage.sh <features_dir>
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
echo "  Frontend Integration Test Coverage"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

# Find all ui/ directories within features
ui_dirs=$(find "$FEATURES_DIR" -type d -name "ui" 2>/dev/null || true)

if [ -z "$ui_dirs" ]; then
  echo ""
  echo "INFO: No ui/ directories found."
  echo "PASSED: No UI features to check."
  exit 0
fi

while IFS= read -r ui_dir; do
  feature_name=$(basename "$(dirname "$ui_dir")")

  tests_dir="${ui_dir}/__tests__"

  if [ ! -d "$tests_dir" ]; then
    echo ""
    echo "FAIL: '$feature_name/ui/' has no __tests__/ directory"
    echo "      Expected: ${feature_name}/ui/__tests__/ with at least one"
    echo "                *.integration.test.tsx file"
    ERRORS=$((ERRORS + 1))
    continue
  fi

  # Check for at least one integration test file
  integration_count=$(find "$tests_dir" -maxdepth 1 -type f -name "*.integration.test.*" 2>/dev/null | wc -l)

  if [ "$integration_count" -eq 0 ]; then
    echo ""
    echo "FAIL: '$feature_name/ui/__tests__/' has no integration test files"
    echo "      Expected: at least one *.integration.test.tsx file"
    echo "      Integration tests verify cross-layer behavior (hook → mapper → API)"
    ERRORS=$((ERRORS + 1))
  fi
done <<< "$ui_dirs"

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS feature(s) without integration tests."
  echo ""
  echo "Rule: Every feature with a ui/ directory must have at least one"
  echo "      integration test file (*.integration.test.tsx) in ui/__tests__/"
  echo ""
  echo "Integration tests should cover:"
  echo "  - Component renders with real hook output (no mocking of hooks)"
  echo "  - User interactions (click, type, submit)"
  echo "  - API calls are made with correct parameters"
  echo "  - Error states and loading states"
  echo "  - Cross-layer data flow (hook → mapper → API response)"
  exit 1
else
  echo "PASSED: All UI features have integration test files."
  exit 0
fi
