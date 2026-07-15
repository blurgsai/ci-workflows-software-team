#!/usr/bin/env bash
#
# Enforces that ALL backend Python code lives under backend/src/.
#
# Blocked patterns (code outside src/):
#   backend/routes/       ← WRONG: should be backend/src/features/<name>/router/
#   backend/utils/        ← WRONG: should be backend/src/shared/
#   backend/config.py     ← WRONG: should be backend/src/shared/config/
#   backend/db.py         ← WRONG: should be backend/src/shared/
#   backend/main.py       ← WRONG: should be backend/src/main.py
#   backend/<anything>.py ← WRONG: must be inside src/
#
# Only these are allowed directly in backend/:
#   requirements.txt, pyproject.toml, .importlinter, .gitignore, .env.example
#   Dockerfile, deploy.sh, README.md, LICENSE, tests/
#
# Usage: ./check-backend-src-enforcement.sh <backend_dir>
#
set -euo pipefail

BACKEND_DIR="${1:-.}"

if [ ! -d "$BACKEND_DIR" ]; then
  echo "INFO: Backend directory '$BACKEND_DIR' does not exist."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Backend src/ Enforcement Check"
echo "  Directory: $BACKEND_DIR"
echo "=========================================="
echo ""
echo "Principle: All backend Python code must live under src/."
echo "  src/features/<name>/{clients,models,services,router}"
echo "  src/shared/{config,dependencies,errors,...}"
echo "  src/main.py"
echo ""

# ─── Check 1: No .py files directly in backend/ ───
echo "Check 1: No loose .py files in backend/ root"
loose_py=$(find "$BACKEND_DIR" -maxdepth 1 -name "*.py" 2>/dev/null || true)
if [ -n "$loose_py" ]; then
  while IFS= read -r py_file; do
    [ -z "$py_file" ] && continue
    filename=$(basename "$py_file")
    echo "  FAIL: backend/$filename — Python files must live under src/"
    case "$filename" in
      main.py)     echo "    → Move to src/main.py" ;;
      config.py)   echo "    → Move to src/shared/config/settings.py" ;;
      db.py)       echo "    → Move to src/shared/dependencies/database.py" ;;
      *)           echo "    → Move to src/shared/ or src/features/<name>/" ;;
    esac
    ERRORS=$((ERRORS + 1))
  done <<< "$loose_py"
else
  echo "  OK: No loose .py files in backend/ root"
fi
echo ""

# ─── Check 2: No routes/ directory (legacy structure) ───
echo "Check 2: No legacy routes/ directory"
if [ -d "$BACKEND_DIR/routes" ]; then
  echo "  FAIL: backend/routes/ exists — this is a legacy structure."
  echo "    All route handlers must live under src/features/<name>/router/"
  echo "    Move each route module to src/features/<name>/router/__init__.py"
  ERRORS=$((ERRORS + 1))
else
  echo "  OK: No routes/ directory"
fi
echo ""

# ─── Check 3: No utils/ directory (legacy structure) ───
echo "Check 3: No legacy utils/ directory"
if [ -d "$BACKEND_DIR/utils" ]; then
  echo "  FAIL: backend/utils/ exists — this is a legacy structure."
  echo "    Shared utilities must live under src/shared/"
  echo "    Move each utility to src/shared/<appropriate_subdir>/"
  ERRORS=$((ERRORS + 1))
else
  echo "  OK: No utils/ directory"
fi
echo ""

# ─── Check 4: src/ directory must exist ───
echo "Check 4: src/ directory exists"
if [ ! -d "$BACKEND_DIR/src" ]; then
  echo "  FAIL: backend/src/ does not exist."
  echo "    All backend code must be organized under src/"
  echo "    Required structure:"
  echo "      src/main.py"
  echo "      src/features/<name>/{clients,models,services,router}/__init__.py"
  echo "      src/shared/{config,dependencies,errors,...}/__init__.py"
  ERRORS=$((ERRORS + 1))
else
  echo "  OK: src/ directory exists"
fi
echo ""

# ─── Check 5: No other unexpected directories in backend/ ───
echo "Check 5: No unexpected directories in backend/ root"
ALLOWED_DIRS=("src" "tests" ".git" "__pycache__" ".venv" "venv" ".ruff_cache" ".pytest_cache" ".import_linter_cache")
for dir in "$BACKEND_DIR"/*/; do
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
    echo "  FAIL: Unexpected directory 'backend/$dirname/'"
    echo "    Only src/, tests/ are allowed as directories in backend/"
    echo "    Move contents to src/features/ or src/shared/"
    ERRORS=$((ERRORS + 1))
  fi
done
if [ "$ERRORS" -eq 0 ] || true; then
  found_unexpected=false
  for dir in "$BACKEND_DIR"/*/; do
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
      found_unexpected=true
    fi
  done
  if [ "$found_unexpected" = false ]; then
    echo "  OK: No unexpected directories"
  fi
fi
echo ""

echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS src/ enforcement violation(s) found."
  echo ""
  echo "Architecture rule: All backend Python code must live under src/."
  echo "  src/main.py              — FastAPI app entry point"
  echo "  src/features/<name>/     — Feature-sliced modules"
  echo "  src/shared/              — Shared config, dependencies, errors"
  echo ""
  echo "Legacy structures (routes/, utils/, loose .py files) are NOT allowed."
  exit 1
else
  echo "PASSED: All backend code is under src/."
  exit 0
fi
