#!/usr/bin/env bash
#
# Enforces that ALL tileserver Python code lives under tileserver/src/.
#
# Only these are allowed directly in tileserver/:
#   requirements.txt, .env.example, .gitignore, Dockerfile, .importlinter
#
# Usage: ./check-tileserver-src-enforcement.sh <tileserver_dir>
#
set -euo pipefail

TS_DIR="${1:-.}"

if [ ! -d "$TS_DIR" ]; then
  echo "INFO: Tileserver directory '$TS_DIR' does not exist."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Tileserver src/ Enforcement Check"
echo "  Directory: $TS_DIR"
echo "=========================================="
echo ""
echo "Principle: All tileserver Python code must live under src/."
echo "  src/features/<name>/{schemas,repository,services,router}"
echo "  src/shared/{config,auth,errors,...}"
echo "  src/main.py"
echo ""

# ─── Check 1: No .py files directly in tileserver/ ───
echo "Check 1: No loose .py files in tileserver/ root"
loose_py=$(find "$TS_DIR" -maxdepth 1 -name "*.py" 2>/dev/null || true)
if [ -n "$loose_py" ]; then
  while IFS= read -r py_file; do
    [ -z "$py_file" ] && continue
    filename=$(basename "$py_file")
    echo "  FAIL: tileserver/$filename — Python files must live under src/"
    ERRORS=$((ERRORS + 1))
  done <<< "$loose_py"
else
  echo "  OK: No loose .py files in tileserver/ root"
fi
echo ""

# ─── Check 2: No legacy directories ───
echo "Check 2: No legacy routes/ or utils/ directories"
for legacy_dir in routes utils routers api; do
  if [ -d "$TS_DIR/$legacy_dir" ]; then
    echo "  FAIL: tileserver/$legacy_dir/ exists — this is a legacy structure."
    echo "    All route handlers must live under src/features/<name>/router/"
    ERRORS=$((ERRORS + 1))
  fi
done
echo "  OK: No legacy directories"
echo ""

# ─── Check 3: src/ directory must exist ───
echo "Check 3: src/ directory exists"
if [ ! -d "$TS_DIR/src" ]; then
  echo "  FAIL: tileserver/src/ does not exist."
  echo "    All tileserver code must be organized under src/"
  ERRORS=$((ERRORS + 1))
else
  echo "  OK: src/ directory exists"
fi
echo ""

# ─── Check 4: No unexpected directories in tileserver/ ───
echo "Check 4: No unexpected directories in tileserver/ root"
ALLOWED_DIRS=("src" "tests" ".git" "__pycache__" ".venv" "venv" ".ruff_cache" ".pytest_cache" ".import_linter_cache" "data")
for dir in "$TS_DIR"/*/; do
  [ -d "$dir" ] || continue
  dirname=$(basename "$dir")

  is_allowed=false
  for allowed in "${ALLOWED_DIRS[@]}"; do
    if [ "$dirname" = "$allowed" ]; then
      is_allowed=true
      break
    fi
  done

  if [ "$is_allowed" = false ]; then
    echo "  FAIL: Unexpected directory 'tileserver/$dirname/'"
    echo "    Only src/, tests/, data/ are allowed as directories in tileserver/"
    ERRORS=$((ERRORS + 1))
  fi
done
echo "  OK: No unexpected directories"
echo ""

echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS src/ enforcement violation(s) found."
  echo ""
  echo "Architecture rule: All tileserver Python code must live under src/."
  echo "  src/main.py              — FastAPI app entry point"
  echo "  src/features/<name>/     — Feature-sliced modules"
  echo "  src/shared/              — Shared config, auth, errors"
  exit 1
else
  echo "PASSED: All tileserver code is under src/."
  exit 0
fi
