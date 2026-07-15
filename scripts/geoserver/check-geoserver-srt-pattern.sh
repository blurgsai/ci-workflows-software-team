#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# check-geoserver-srt-pattern.sh
#
# Enforces the Service Replication Template (SRT) design pattern for the
# geoserver/ directory. Every offline-replicable service must follow:
#
#   <service>/
#   ├── docker-compose.yml    # Declarative orchestration with healthchecks
#   ├── .env.example          # All env vars documented, NO real secrets
#   ├── .gitignore            # Ignore data/, logs/, .env
#   ├── start.sh              # Single-command startup (executable)
#   ├── stop.sh               # Clean shutdown (executable)
#   ├── scripts/              # Idempotent provisioning scripts
#   ├── config/               # Version-controlled config files
#   ├── data/                 # Data directory (gitignored)
#   └── README.md             # Architecture + setup instructions
#
# Usage: check-geoserver-srt-pattern.sh <service_dir>
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

SERVICE_DIR="${1:-}"
if [ -z "$SERVICE_DIR" ] || [ ! -d "$SERVICE_DIR" ]; then
    echo "ERROR: Service directory not provided or does not exist."
    echo "Usage: $0 <service_dir>"
    exit 1
fi

cd "$SERVICE_DIR"
ERRORS=0

check_exists() {
    local path="$1"
    local label="$2"
    if [ ! -e "$path" ]; then
        echo "FAIL: Missing required file: $path ($label)"
        ERRORS=$((ERRORS + 1))
    fi
}

check_executable() {
    local path="$1"
    local label="$2"
    if [ ! -f "$path" ]; then
        echo "FAIL: Missing required script: $path ($label)"
        ERRORS=$((ERRORS + 1))
    elif [ ! -x "$path" ]; then
        echo "FAIL: $path is not executable ($label)"
        ERRORS=$((ERRORS + 1))
    fi
}

check_dir() {
    local path="$1"
    local label="$2"
    if [ ! -d "$path" ]; then
        echo "FAIL: Missing required directory: $path ($label)"
        ERRORS=$((ERRORS + 1))
    fi
}

check_gitignore_pattern() {
    local pattern="$1"
    local label="$2"
    if [ ! -f ".gitignore" ]; then
        echo "FAIL: .gitignore missing — cannot check pattern: $pattern ($label)"
        ERRORS=$((ERRORS + 1))
        return
    fi
    if ! grep -qE "^${pattern}" .gitignore 2>/dev/null; then
        echo "FAIL: .gitignore must contain pattern: $pattern ($label)"
        ERRORS=$((ERRORS + 1))
    fi
}

check_no_secrets_in_env_example() {
    if [ ! -f ".env.example" ]; then
        echo "FAIL: Missing .env.example"
        ERRORS=$((ERRORS + 1))
        return
    fi
    # Check for common secret patterns that should NOT be in .env.example
    local secret_patterns=(
        "SecurePassword"
        "password123"
        "secret_key_here"
        "CHANGE_ME_TO_REAL"
    )
    for pattern in "${secret_patterns[@]}"; do
        if grep -qi "$pattern" .env.example 2>/dev/null; then
            echo "FAIL: .env.example appears to contain real secret: $pattern"
            ERRORS=$((ERRORS + 1))
        fi
    done
    # Every line should use placeholder format (VALUE or <value> or changeme)
    while IFS= read -r line; do
        line=$(echo "$line" | sed 's/#.*//' | xargs)
        [ -z "$line" ] && continue
        local key
        key=$(echo "$line" | cut -d'=' -f1)
        local val
        val=$(echo "$line" | cut -d'=' -f2-)
        if [ "$key" = "$line" ]; then
            echo "WARN: .env.example line has no '=' separator: $line"
            continue
        fi
    done < .env.example
}

check_docker_compose_healthchecks() {
    if [ ! -f "docker-compose.yml" ]; then
        echo "FAIL: Missing docker-compose.yml"
        ERRORS=$((ERRORS + 1))
        return
    fi
    # Every service should have a healthcheck or depends_on with healthy condition
    local service_count
    service_count=$(grep -cE '^\s+[a-zA-Z_-]+:\s*$' docker-compose.yml 2>/dev/null || echo 0)
    local healthcheck_count
    healthcheck_count=$(grep -c 'healthcheck:' docker-compose.yml 2>/dev/null || echo 0)
    if [ "$service_count" -gt 0 ] && [ "$healthcheck_count" -eq 0 ]; then
        echo "FAIL: docker-compose.yml has services but no healthchecks defined"
        ERRORS=$((ERRORS + 1))
    fi
}

check_scripts_have_init() {
    if [ ! -d "scripts" ]; then
        echo "FAIL: Missing scripts/ directory"
        ERRORS=$((ERRORS + 1))
        return
    fi
    local script_count
    script_count=$(find scripts/ -name '*.sh' -type f 2>/dev/null | wc -l)
    if [ "$script_count" -eq 0 ]; then
        echo "FAIL: scripts/ directory must contain at least one .sh script"
        ERRORS=$((ERRORS + 1))
    fi
}

check_readme_has_sections() {
    if [ ! -f "README.md" ]; then
        echo "FAIL: Missing README.md"
        ERRORS=$((ERRORS + 1))
        return
    fi
    local required_sections=("## Quick Start" "## Architecture" "## Configuration")
    for section in "${required_sections[@]}"; do
        if ! grep -qF "$section" README.md 2>/dev/null; then
            echo "FAIL: README.md missing section: $section"
            ERRORS=$((ERRORS + 1))
        fi
    done
}

# ── Run all checks ────────────────────────────────────────────────────────────

echo "=== SRT Pattern Check: $(basename "$SERVICE_DIR") ==="

# Check 0: Required files
check_exists "docker-compose.yml" "declarative orchestration"
check_exists ".env.example" "environment template"
check_exists ".gitignore" "gitignore rules"
check_exists "README.md" "documentation"

# Check 1: Required executable scripts
check_executable "start.sh" "single-command startup"
check_executable "stop.sh" "clean shutdown"

# Check 2: Required directories
check_dir "scripts" "provisioning scripts"
check_dir "config" "version-controlled config"

# Check 3: .gitignore must ignore runtime artifacts
check_gitignore_pattern "data/" "ignore data directory"
check_gitignore_pattern "logs/" "ignore logs directory"
check_gitignore_pattern ".env" "ignore .env file"

# Check 4: .env.example must not contain real secrets
check_no_secrets_in_env_example

# Check 5: docker-compose.yml must have healthchecks
check_docker_compose_healthchecks

# Check 6: scripts/ must have at least one init script
check_scripts_have_init

# Check 7: README.md must have required sections
check_readme_has_sections

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "RESULT: FAIL ($ERRORS error(s))"
    exit 1
else
    echo "RESULT: PASS — SRT pattern validated"
    exit 0
fi
