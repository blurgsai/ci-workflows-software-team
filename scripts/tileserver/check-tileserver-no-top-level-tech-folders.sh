#!/usr/bin/env bash
#
# Enforces that tileserver src/ does NOT contain top-level technical-role folders.
# All code must live inside src/features/<feature>/ or src/shared/
#
# Usage: ./check-tileserver-no-top-level-tech-folders.sh <src_dir>
#
set -euo pipefail

SRC_DIR="${1:-src}"

if [ ! -d "$SRC_DIR" ]; then
  echo "INFO: Source directory '$SRC_DIR' does not exist."
  exit 0
fi

ERRORS=0

VALID_TOP_LEVEL=("features" "shared")

BLOCKED_FOLDERS=(
  "models" "routes" "routers" "schemas" "services" "repository"
  "api" "endpoints" "db" "database" "utils" "core" "config"
  "dependencies" "errors" "exceptions" "middleware" "types"
  "common" "helpers" "lib" "domain" "crud" "repositories" "dao"
)

echo "=========================================="
echo "  Tileserver Top-Level Tech Folder Check"
echo "  Directory: $SRC_DIR"
echo "=========================================="
echo ""
echo "Principle: Code is organized by feature, not by technical role."
echo "Allowed top-level: ${VALID_TOP_LEVEL[*]}"
echo ""

for dir in "$SRC_DIR"/*/; do
  [ -d "$dir" ] || continue

  dirname=$(basename "$dir")
  [ "$dirname" = "__pycache__" ] && continue

  is_valid=false
  for valid in "${VALID_TOP_LEVEL[@]}"; do
    if [ "$dirname" = "$valid" ]; then
      is_valid=true
      break
    fi
  done

  if [ "$is_valid" = false ]; then
    is_blocked=false
    for blocked in "${BLOCKED_FOLDERS[@]}"; do
      if [ "$dirname" = "$blocked" ]; then
        is_blocked=true
        break
      fi
    done

    if [ "$is_blocked" = true ]; then
      echo "FAIL: Found top-level '/$dirname' folder."
      echo "  This is a technical-role folder — code should be organized by feature."
      echo "  Move contents to src/features/<feature>/ or src/shared/"
      ERRORS=$((ERRORS + 1))
    else
      echo "FAIL: Unknown top-level folder '/$dirname'."
      echo "  Only these are allowed: ${VALID_TOP_LEVEL[*]}"
      ERRORS=$((ERRORS + 1))
    fi
    echo ""
  fi
done

echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS top-level folder violation(s) found."
  echo ""
  echo "Architecture rule: Code is organized by feature, not by technical role."
  echo "  src/features/  — Feature-sliced modules (each self-contained)"
  echo "  src/shared/     — Config, auth, errors, cross-cutting concerns"
  echo "  src/main.py     — App factory, router registration"
  exit 1
else
  echo "PASSED: No top-level technical-role folders detected."
  exit 0
fi
