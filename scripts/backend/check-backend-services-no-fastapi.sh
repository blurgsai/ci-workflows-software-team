#!/usr/bin/env bash
#
# Enforces that services are independent of FastAPI:
#
# From the guide §4 Layer 3 Rules:
#   "Services are independent of FastAPI (no Request/Response objects)"
#
# Checks that services/ files do NOT import:
#   - fastapi.Request
#   - fastapi.Response
#   - fastapi.APIRouter
#   - fastapi.Depends
#   - fastapi.HTTPException
#   - fastapi.Query / Path / Body / Header / Cookie
#   - Any fastapi.* import
#
# Services should be pure Python — they handle business logic, not HTTP.
# Error handling uses shared/errors/ exceptions, NOT fastapi.HTTPException.
#
# Usage: ./check-backend-services-no-fastapi.sh <features_dir>
#
set -euo pipefail

FEATURES_DIR="${1:-src/features}"

if [ ! -d "$FEATURES_DIR" ]; then
  echo "INFO: Features directory '$FEATURES_DIR' does not exist yet."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Backend Services FastAPI Independence"
echo "  Directory: $FEATURES_DIR"
echo "=========================================="

# FastAPI imports that should NEVER appear in services/
FORBIDDEN_PATTERNS=(
  "from\s+fastapi\s+import"
  "import\s+fastapi"
  "from\s+fastapi\."
  "APIRouter"
  "fastapi\.Request"
  "fastapi\.Response"
  "fastapi\.Depends"
  "fastapi\.HTTPException"
  "fastapi\.Query"
  "fastapi\.Path"
  "fastapi\.Body"
  "fastapi\.Header"
  "fastapi\.Cookie"
  "fastapi\.Form"
  "fastapi\.File"
  "fastapi\.UploadFile"
  "fastapi\.BackgroundTasks"
  "fastapi\.WebSocket"
)

for feature_dir in "$FEATURES_DIR"/*/; do
  [ -d "$feature_dir" ] || continue

  feature_name=$(basename "$feature_dir")
  services_dir="${feature_dir}services"

  [ -d "$services_dir" ] || continue

  echo ""
  echo "Feature: $feature_name"

  while IFS= read -r service_file; do
    [ -f "$service_file" ] || continue
    rel_path="${service_file#${feature_dir}}"
    filename=$(basename "$service_file")

    # Skip __init__.py if it's just a package marker with no real code
    for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
      if grep -qE "$pattern" "$service_file" 2>/dev/null; then
        echo "  FAIL: $rel_path contains FastAPI import: $pattern"
        echo "    Services must be independent of FastAPI."
        echo "    No Request, Response, APIRouter, Depends, HTTPException, etc."
        echo "    Use shared/errors/ exceptions for error handling."
        echo "    Use shared/dependencies/ for dependency injection."
        ERRORS=$((ERRORS + 1))
      fi
    done
  done < <(find "${services_dir}" -name "*.py" 2>/dev/null)
done

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS FastAPI dependency violation(s) in services."
  echo ""
  echo "Rule: Services are independent of FastAPI."
  echo "  Forbidden in services/:"
  echo "    - from fastapi import ... (anything)"
  echo "    - APIRouter, Request, Response, Depends"
  echo "    - HTTPException, Query, Path, Body, Header, Cookie"
  echo ""
  echo "  Instead use:"
  echo "    - shared/errors/ for exception classes (ExternalServiceError, NotFoundError)"
  echo "    - shared/dependencies/ for dependency injection (get_http_client, get_db)"
  exit 1
else
  echo "PASSED: All services are independent of FastAPI."
  exit 0
fi
