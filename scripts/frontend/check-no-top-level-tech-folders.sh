#!/usr/bin/env bash
#
# Enforces Principle #1 from the architecture guide:
#   "Code is organized by feature, not by technical role
#    (no top-level /components, /hooks, /utils folders)"
#
# Checks that src/ does NOT contain top-level technical-role folders.
# All code must live inside src/features/<feature>/ or src/shared/ or src/app/
#
# Blocked patterns:
#   src/components/      ← WRONG: should be in features or shared
#   src/hooks/           ← WRONG: should be in features
#   src/utils/           ← WRONG: should be in shared
#   src/services/        ← WRONG: should be in features
#   src/types/           ← WRONG: should be in shared or model
#   src/store/           ← WRONG: should be in app or features
#   src/api/             ← WRONG: should be in features
#   src/pages/           ← WRONG: should be in app/pages
#   src/routes/          ← WRONG: should be in app
#   src/context/         ← WRONG: should be in app or shared
#   src/constants/       ← WRONG: should be in shared
#   src/config/          ← WRONG: should be in shared
#   src/lib/             ← WRONG: should be in shared
#   src/helpers/         ← WRONG: should be in shared
#
# Usage: ./check-no-top-level-tech-folders.sh <src_dir>
#
set -euo pipefail

SRC_DIR="${1:-src}"

if [ ! -d "$SRC_DIR" ]; then
  echo "INFO: Source directory '$SRC_DIR' does not exist yet."
  exit 0
fi

ERRORS=0

# Valid top-level directories inside src/
VALID_TOP_LEVEL=("app" "features" "shared" "assets" "test")

# Folders that indicate technical-role organization (anti-pattern)
BLOCKED_FOLDERS=(
  "components"
  "hooks"
  "utils"
  "services"
  "types"
  "store"
  "api"
  "pages"
  "routes"
  "router"
  "context"
  "constants"
  "config"
  "lib"
  "helpers"
  "schemas"
  "models"
  "middleware"
  "providers"
)

echo "=========================================="
echo "  Top-Level Tech Folder Check"
echo "  Directory: $SRC_DIR"
echo "=========================================="
echo ""
echo "Principle: Code is organized by feature, not by technical role."
echo "Allowed top-level: ${VALID_TOP_LEVEL[*]}"
echo ""

for dir in "$SRC_DIR"/*/; do
  [ -d "$dir" ] || continue

  dirname=$(basename "$dir")

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
        components)  echo "    → src/shared/ui/ for reusable components" ;;
        hooks)       echo "    → src/features/<feature>/hooks/ for feature hooks"
                     echo "    → src/shared/ for shared hooks" ;;
        utils|lib|helpers|constants|config)
                     echo "    → src/shared/utils/ for shared utilities" ;;
        services)    echo "    → src/features/<feature>/hooks/ for data logic" ;;
        types)       echo "    → src/shared/types/ for shared types"
                     echo "    → src/features/<feature>/model/types.ts for domain types" ;;
        store)       echo "    → src/app/ for app-level state" ;;
        api)         echo "    → src/features/<feature>/api/ for API calls" ;;
        pages)       echo "    → src/app/pages/ for page components" ;;
        routes|router)
                     echo "    → src/app/router.tsx for routing" ;;
        context)     echo "    → src/app/providers.tsx for context providers" ;;
        schemas|models)
                     echo "    → src/features/<feature>/model/ for domain models" ;;
        middleware)  echo "    → src/shared/ for shared middleware" ;;
        providers)   echo "    → src/app/providers.tsx for providers" ;;
        *)           echo "    → Move to src/features/, src/shared/, or src/app/" ;;
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

# ─── Also check one level inside src/app/ ───
# app/ legitimately holds routing, providers, layout, and page-level components
# (pages/, routes/, components/ for app-shell pieces like Layout/Header/Sidebar
# are allowed per the guide). But feature/business logic folders must never
# live under app/ — that would bypass the feature-sliced architecture entirely.
APP_DIR="${SRC_DIR}/app"
APP_BLOCKED_FOLDERS=("hooks" "utils" "api" "services" "store" "model" "models" "schemas" "middleware")

if [ -d "$APP_DIR" ]; then
  for dir in "$APP_DIR"/*/; do
    [ -d "$dir" ] || continue
    dirname=$(basename "$dir")

    for blocked in "${APP_BLOCKED_FOLDERS[@]}"; do
      if [ "$dirname" = "$blocked" ]; then
        echo "FAIL: Found 'app/$dirname/' folder."
        echo "  Business/feature logic must not live under src/app/."
        echo "  Move contents to src/features/<feature>/$dirname/ or src/shared/"
        echo ""
        ERRORS=$((ERRORS + 1))
      fi
    done
  done
fi

echo "=========================================="
if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: $ERRORS top-level folder violation(s) found."
  echo ""
  echo "Architecture rule: Code is organized by feature, not by technical role."
  echo "  src/app/       — Routes, providers, layout, page-level components"
  echo "  src/features/  — Feature-sliced modules (each self-contained)"
  echo "  src/shared/    — Reusable UI components, utils, types"
  exit 1
else
  echo "PASSED: No top-level technical-role folders detected."
  exit 0
fi
