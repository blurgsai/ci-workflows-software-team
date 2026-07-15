#!/usr/bin/env bash
#
# Enforces Principle #1 from the FastAPI architecture guide:
#   "Code is organized by feature, not by technical role
#    (no top-level /models, /routes, /schemas folders)"
#
# Checks that src/ does NOT contain top-level technical-role folders.
# All code must live inside src/features/<feature>/ or src/shared/ or src/app/
#
# Blocked patterns:
#   src/models/          ← WRONG: should be in features
#   src/routes/          ← WRONG: should be in features
#   src/schemas/         ← WRONG: should be in features/clients
#   src/services/        ← WRONG: should be in features
#   src/clients/         ← WRONG: should be in features
#   src/routers/         ← WRONG: should be in features
#   src/api/             ← WRONG: should be in features/router
#   src/endpoints/       ← WRONG: should be in features/router
#   src/db/              ← WRONG: should be in shared/dependencies
#   src/utils/           ← WRONG: should be in shared
#   src/core/            ← WRONG: should be in shared
#   src/config/          ← WRONG: should be in shared/config
#   src/dependencies/    ← WRONG: should be in shared/dependencies
#   src/errors/          ← WRONG: should be in shared/errors
#   src/exceptions/      ← WRONG: should be in shared/errors
#   src/middleware/      ← WRONG: should be in shared
#   src/types/           ← WRONG: should be in shared
#   src/common/          ← WRONG: should be in shared
#   src/helpers/         ← WRONG: should be in shared
#   src/lib/             ← WRONG: should be in shared
#
# Usage: ./check-backend-no-top-level-tech-folders.sh <src_dir>
#
set -euo pipefail

SRC_DIR="${1:-src}"

if [ ! -d "$SRC_DIR" ]; then
  echo "INFO: Source directory '$SRC_DIR' does not exist yet."
  exit 0
fi

ERRORS=0

# Valid top-level directories inside src/
VALID_TOP_LEVEL=("features" "shared")

# Folders that indicate technical-role organization (anti-pattern)
BLOCKED_FOLDERS=(
  "models"
  "routes"
  "routers"
  "schemas"
  "services"
  "clients"
  "api"
  "endpoints"
  "db"
  "database"
  "utils"
  "core"
  "config"
  "dependencies"
  "errors"
  "exceptions"
  "middleware"
  "types"
  "common"
  "helpers"
  "lib"
  "domain"
  "crud"
  "repositories"
  "dao"
)

echo "=========================================="
echo "  Backend Top-Level Tech Folder Check"
echo "  Directory: $SRC_DIR"
echo "=========================================="
echo ""
echo "Principle: Code is organized by feature, not by technical role."
echo "Allowed top-level: ${VALID_TOP_LEVEL[*]}"
echo ""

for dir in "$SRC_DIR"/*/; do
  [ -d "$dir" ] || continue

  dirname=$(basename "$dir")

  # __pycache__ is a Python runtime artifact, not a top-level folder — skip it.
  [ "$dirname" = "__pycache__" ] && continue

  # Check if it's a valid top-level directory
  is_valid=false
  for valid in "${VALID_TOP_LEVEL[@]}"; do
    if [ "$dirname" = "$valid" ]; then
      is_valid=true
      break
    fi
  done

  if [ "$is_valid" = false ]; then
    # Check if it's a known anti-pattern folder
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
      echo "  Move contents to:"
      case "$dirname" in
        models|domain)
          echo "    → src/features/<feature>/models/ for domain models + mappers" ;;
        routes|routers|api|endpoints)
          echo "    → src/features/<feature>/router/ for FastAPI route handlers" ;;
        schemas)
          echo "    → src/features/<feature>/clients/ for raw external schemas" ;;
        services)
          echo "    → src/features/<feature>/services/ for business logic" ;;
        clients)
          echo "    → src/features/<feature>/clients/ for external API clients" ;;
        db|database|crud|repositories|dao)
          echo "    → src/features/<feature>/clients/ for data access"
          echo "    → src/shared/dependencies/ for DB session management" ;;
        utils|lib|helpers|common)
          echo "    → src/shared/ for shared utilities" ;;
        core|config)
          echo "    → src/shared/config/ for app settings" ;;
        dependencies)
          echo "    → src/shared/dependencies/ for FastAPI DI" ;;
        errors|exceptions)
          echo "    → src/shared/errors/ for shared exception classes" ;;
        middleware)
          echo "    → src/shared/ for shared middleware" ;;
        types)
          echo "    → src/shared/ for shared types" ;;
        *)
          echo "    → Move to src/features/ or src/shared/" ;;
      esac
      ERRORS=$((ERRORS + 1))
    else
      echo "FAIL: Unknown top-level folder '/$dirname'."
      echo "  Only these are allowed: ${VALID_TOP_LEVEL[*]}"
      echo "  If this is a new feature, place it under src/features/$dirname/"
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
  echo "  src/shared/     — Config, dependencies, errors, cross-cutting concerns"
  echo "  src/main.py     — App factory, router registration"
  exit 1
else
  echo "PASSED: No top-level technical-role folders detected."
  exit 0
fi
