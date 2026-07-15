#!/usr/bin/env bash
#
# Enforces coding-standards naming conventions for the tileserver.
#
# Checks:
#   1. File names: snake_case.py (except __init__.py, conftest.py, test_*.py)
#   2. Class names: PascalCase
#   3. Function names: snake_case
#   4. Method names: snake_case
#   5. Module-level variables: snake_case or UPPER_SNAKE_CASE
#   6. Local variables: snake_case (no camelCase)
#   7. Test files: must start with test_ prefix
#
# Usage: ./check-tileserver-naming-conventions.sh <src_dir>
#
set -euo pipefail

SRC_DIR="${1:-src}"

if [ ! -d "$SRC_DIR" ]; then
  echo "INFO: Source directory '$SRC_DIR' does not exist."
  exit 0
fi

ERRORS=0

echo "=========================================="
echo "  Tileserver Naming Convention Check"
echo "  Directory: $SRC_DIR"
echo "=========================================="

is_pascal_case() { [[ "$1" =~ ^[A-Z][a-zA-Z0-9]*$ ]]; }
is_snake_case() { [[ "$1" =~ ^_?[a-z][a-z0-9_]*$ ]]; }
is_upper_snake_case() { [[ "$1" =~ ^[A-Z][A-Z0-9_]*$ ]]; }
is_camel_case() { [[ "$1" =~ ^[a-z][a-zA-Z0-9]*$ ]] && [[ "$1" =~ [A-Z] ]]; }

# ── Check 1: File naming ──
echo ""
echo "-- Check 1: File naming conventions (snake_case.py) --"
while IFS= read -r py_file; do
  [ -f "$py_file" ] || continue
  filename=$(basename "$py_file")
  stem="${filename%.py}"
  case "$filename" in
    __init__.py|conftest.py|setup.py|__main__.py) continue ;;
  esac
  [[ "$filename" == test_*.py ]] && continue
  if ! is_snake_case "$stem"; then
    echo "  FAIL: '$py_file' -- Python files must use snake_case naming"
    ERRORS=$((ERRORS + 1))
  fi
done < <(find "$SRC_DIR" -type f -name "*.py" -not -path "*/__pycache__/*" 2>/dev/null || true)

# ── Check 2: Class names must be PascalCase ──
echo ""
echo "-- Check 2: Class names must be PascalCase --"
while IFS= read -r py_file; do
  [ -f "$py_file" ] || continue
  while IFS= read -r class_name; do
    [ -z "$class_name" ] && continue
    if ! is_pascal_case "$class_name"; then
      echo "  FAIL: '$py_file' -- class '$class_name' must be PascalCase"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(grep -oE '^class [a-zA-Z_][a-zA-Z0-9_]*' "$py_file" 2>/dev/null | sed 's/^class //' || true)
done < <(find "$SRC_DIR" -type f -name "*.py" -not -path "*/__pycache__/*" 2>/dev/null || true)

# ── Check 3: Function names must be snake_case ──
echo ""
echo "-- Check 3: Function names must be snake_case --"
while IFS= read -r py_file; do
  [ -f "$py_file" ] || continue
  while IFS= read -r func_name; do
    [ -z "$func_name" ] && continue
    [[ "$func_name" == __*__ ]] && continue
    if ! is_snake_case "$func_name"; then
      echo "  FAIL: '$py_file' -- function '$func_name' must be snake_case"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(grep -oE '^(async )?def [a-zA-Z_][a-zA-Z0-9_]*' "$py_file" 2>/dev/null | sed -E 's/^(async )?def //' || true)
done < <(find "$SRC_DIR" -type f -name "*.py" -not -path "*/__pycache__/*" 2>/dev/null || true)

# ── Check 4: Method names must be snake_case ──
echo ""
echo "-- Check 4: Method names must be snake_case --"
while IFS= read -r py_file; do
  [ -f "$py_file" ] || continue
  while IFS= read -r method_name; do
    [ -z "$method_name" ] && continue
    [[ "$method_name" == __*__ ]] && continue
    if ! is_snake_case "$method_name"; then
      echo "  FAIL: '$py_file' -- method '$method_name' must be snake_case"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(grep -oE '^    (async )?def [a-zA-Z_][a-zA-Z0-9_]*' "$py_file" 2>/dev/null | sed -E 's/^    (async )?def //' || true)
done < <(find "$SRC_DIR" -type f -name "*.py" -not -path "*/__pycache__/*" 2>/dev/null || true)

# ── Check 5: Module-level variables ──
echo ""
echo "-- Check 5: Module-level variables must be snake_case or UPPER_SNAKE_CASE --"
while IFS= read -r py_file; do
  [ -f "$py_file" ] || continue
  filename=$(basename "$py_file")
  [ "$filename" = "__init__.py" ] && continue
  while IFS= read -r line; do
    var_name=$(echo "$line" | sed -nE 's/^([a-zA-Z_][a-zA-Z0-9_]*) =.*/\1/p')
    [ -z "$var_name" ] && continue
    if ! is_snake_case "$var_name" && ! is_upper_snake_case "$var_name"; then
      echo "  FAIL: '$py_file' -- module-level variable '$var_name' must be snake_case or UPPER_SNAKE_CASE"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(grep -E '^[a-zA-Z_][a-zA-Z0-9_]* = ' "$py_file" 2>/dev/null | grep -vE '^(def |class |import |from |@)' || true)
done < <(find "$SRC_DIR" -type f -name "*.py" -not -path "*/__pycache__/*" 2>/dev/null || true)

# ── Check 6: No camelCase local variables ──
echo ""
echo "-- Check 6: No camelCase local variable assignments --"
while IFS= read -r py_file; do
  [ -f "$py_file" ] || continue
  while IFS= read -r line; do
    var_name=$(echo "$line" | sed -nE 's/^\s+([a-zA-Z_][a-zA-Z0-9_]*) =.*/\1/p')
    [ -z "$var_name" ] && continue
    if is_snake_case "$var_name" || is_upper_snake_case "$var_name"; then continue; fi
    if is_camel_case "$var_name"; then
      echo "  FAIL: '$py_file' -- variable '$var_name' must be snake_case"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(grep -E '^\s+[a-zA-Z_][a-zA-Z0-9_]* = ' "$py_file" 2>/dev/null | grep -vE '^\s+(def |class |import |from |@|self\.|return |if |for |while |elif |else:)' || true)
done < <(find "$SRC_DIR" -type f -name "*.py" -not -path "*/__pycache__/*" 2>/dev/null || true)

# ── Check 7: Test files ──
echo ""
echo "-- Check 7: Test files must start with 'test_' prefix --"
while IFS= read -r test_file; do
  [ -f "$test_file" ] || continue
  filename=$(basename "$test_file")
  [ "$filename" = "conftest.py" ] && continue
  [ "$filename" = "__init__.py" ] && continue
  if [[ "$filename" != test_*.py ]]; then
    echo "  FAIL: '$test_file' -- test files must start with 'test_' prefix"
    ERRORS=$((ERRORS + 1))
  fi
done < <(find "$SRC_DIR" -type d -name "tests" 2>/dev/null | while IFS= read -r test_dir; do
  find "$test_dir" -maxdepth 1 -type f -name "*.py" -not -path "*/__pycache__/*"
done || true)

if [ -d "tests" ]; then
  while IFS= read -r test_file; do
    [ -f "$test_file" ] || continue
    filename=$(basename "$test_file")
    [ "$filename" = "conftest.py" ] && continue
    [ "$filename" = "__init__.py" ] && continue
    if [[ "$filename" != test_*.py ]]; then
      echo "  FAIL: '$test_file' -- test files must start with 'test_' prefix"
      ERRORS=$((ERRORS + 1))
    fi
  done < <(find "tests" -maxdepth 1 -type f -name "*.py" -not -path "*/__pycache__/*" 2>/dev/null || true)
fi

echo ""
echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS naming convention violation(s) found."
  exit 1
else
  echo "PASSED: All naming conventions are correct."
  exit 0
fi
