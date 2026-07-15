#!/usr/bin/env bash
#
# Warns when frontend source files use mock/prototype data sources
# instead of calling a real backend API.
#
# Detects two patterns:
#   1. fetch() calls to static JSON files in the Vite public/ directory
#      (e.g. fetch('/country-prefixes.json'), fetch('/mock/playback/foo.json'))
#   2. localStorage usage as a data store (getItem/setItem/removeItem/clear)
#      (e.g. localStorage.getItem('mapConfig'), localStorage.setItem('filters', ...))
#
# Excludes:
#   - Test files (*.test.*, *.spec.*, __tests__/)
#   - shared/ directory (infrastructure: axios client, useLocalStorage hook)
#   - Auth-token pattern: localStorage.getItem("token") / setItem("token", ...)
#
# This is a WARNING-only check — it always exits 0 so CI never fails.
#
# Usage: ./check-frontend-mock-json-usage.sh <src_dir>
#
set -euo pipefail

SRC_DIR="${1:-src}"

if [ ! -d "$SRC_DIR" ]; then
  echo "INFO: Source directory '$SRC_DIR' does not exist."
  exit 0
fi

WARNINGS=0

echo "=========================================="
echo "  Frontend Mock Data Source Check (WARNING)"
echo "  Directory: $SRC_DIR"
echo "=========================================="

# Scan all .ts/.tsx files, excluding test files, __tests__ dirs, and shared/
while IFS= read -r filepath; do
  [ -f "$filepath" ] || continue

  filename=$(basename "$filepath")

  # Skip test files
  [[ "$filename" == *.test.* ]] || [[ "$filename" == *.spec.* ]] && continue

  # Skip files inside __tests__ directories
  [[ "$filepath" == */__tests__/* ]] && continue

  # Skip shared/ directory — infrastructure code (axios client, useLocalStorage hook)
  [[ "$filepath" == */shared/* ]] && continue

  # ── Check 1: fetch() to static public JSON ──
  # Matches fetch() calls whose URL starts with '/' and contains '.json'
  # Excludes URLs starting with ${...} (those use a real API base URL)
  while IFS= read -r line; do
    [ -z "$line" ] && continue
    echo "  ⚠️  WARNING: '$filepath' fetches static JSON from public/ instead of calling a backend API"
    echo "      $line"
    echo "      Consider replacing with a real API endpoint via axiosInstance."
    echo ""
    WARNINGS=$((WARNINGS + 1))
  done < <(grep -nE "fetch\(\s*['\"\`]/[^'\"]*\.json" "$filepath" 2>/dev/null || true)

  # ── Check 2: localStorage as data store ──
  # Matches localStorage.getItem / setItem / removeItem / clear
  # Excludes auth-token pattern: localStorage.*("token" / 'token')
  while IFS= read -r line; do
    [ -z "$line" ] && continue

    # Skip auth-session fields — legitimate pattern (token, username, role, user_id)
    if echo "$line" | grep -qE "localStorage\.(getItem|setItem|removeItem)\(\s*['\"](token|username|role|user_id)['\"]" 2>/dev/null; then
      continue
    fi

    echo "  ⚠️  WARNING: '$filepath' uses localStorage as a data store instead of calling a backend API"
    echo "      $line"
    echo "      Consider replacing with a real API endpoint via axiosInstance."
    echo ""
    WARNINGS=$((WARNINGS + 1))
  done < <(grep -nE "localStorage\.(getItem|setItem|removeItem|clear)\b" "$filepath" 2>/dev/null || true)

done < <(find "$SRC_DIR" -type f \( -name "*.ts" -o -name "*.tsx" \) \
  -not -path "*/node_modules/*" -not -path "*/dist/*" -not -path "*/build/*" 2>/dev/null || true)

# ── Summary ──────────────────────────────────────────────────────────────
echo "=========================================="
if [ "$WARNINGS" -gt 0 ]; then
  echo "⚠️  $WARNINGS warning(s): mock/prototype data source(s) detected."
  echo ""
  echo "These are WARNINGS only — CI will not fail."
  echo "Replace public JSON fetches and localStorage data stores with real backend API calls before production."
  echo ""
  echo "Common patterns to look for:"
  echo "  fetch('/country-prefixes.json')        →  axiosInstance.get('/country-prefixes')"
  echo "  fetch('/eez-regions.json')             →  axiosInstance.get('/eez-regions')"
  echo "  fetch('/mock/playback/foo.json')       →  axiosInstance.get('/playback/foo')"
  echo "  localStorage.getItem('mapConfig')      →  axiosInstance.get('/map-config')"
  echo "  localStorage.setItem('filters', ...)   →  axiosInstance.post('/filters', ...)"
else
  echo "✅ No mock/prototype data sources found."
fi
echo "=========================================="

# Always exit 0 — this is a warning, not an error
exit 0
