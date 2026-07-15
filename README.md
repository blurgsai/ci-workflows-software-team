# CI Workflows — Software Team

Centralized GitHub Actions workflows, architecture validation scripts, and shared linting configs for all software team repositories.

## Repository Structure

```
ci-workflows-software-team/
├── .github/workflows/          # Reusable GitHub Actions workflows (workflow_call)
│   ├── dev-ci.yml              # Orchestrator: all checks EXCEPT tests (for dev branch)
│   ├── staging-ci.yml          # Orchestrator: tests only + source change rejection (for staging)
│   ├── reject-source-code-changes.yml  # Rejects PRs that modify source code on staging
│   ├── backend-coding-standards-check.yml
│   ├── backend-design-pattern-check.yml
│   ├── backend-test-check.yml
│   ├── frontend-coding-standards-check.yml
│   ├── frontend-design-pattern-check.yml
│   ├── frontend-mock-json-check.yml
│   ├── frontend-test-check.yml
│   ├── tileserver-coding-standards-check.yml
│   ├── tileserver-design-pattern-check.yml
│   └── geoserver-srt-pattern-check.yml
├── templates/                  # Copy these to YOUR repo's .github/workflows/
│   ├── dev-ci.yml              # Trigger for dev branch (all checks except tests)
│   └── staging-ci.yml          # Trigger for staging branch (tests only + source gate)
├── scripts/                    # Bash validation scripts
│   ├── backend/                # Backend (FastAPI) architecture checks
│   ├── frontend/               # Frontend (React/TS) architecture checks
│   ├── tileserver/             # Tileserver architecture checks
│   └── geoserver/              # GeoServer SRT pattern checks
└── configs/                    # Shared configuration files
    ├── eslint/                 # Shared ESLint config (npm package)
    │   ├── package.json
    │   └── index.js
    └── python/                 # Python linting configs
        ├── backend-pyproject.toml    # Ruff config for backend
        ├── backend-importlinter      # import-linter contracts for backend
        └── tileserver-importlinter   # import-linter contracts for tileserver
```

## Branch Strategy

| Branch | What runs | What doesn't run |
|--------|-----------|------------------|
| `dev`  | Coding standards, design patterns, mock JSON check, SRT pattern | Tests |
| `staging` | Tests only + source code change rejection | Coding standards, design patterns, mock JSON, SRT |

- **Dev branch**: All architecture and coding standard checks run. Tests are skipped — dev is for active development.
- **Staging branch**: Only tests run. Additionally, if any source code files (`*.py`, `*.ts`, `*.tsx`, `*.js`, `*.jsx` under `src/`) are changed, the PR is **rejected**. Staging should only receive non-source changes (configs, tests, docs, CI, infrastructure).

## Usage

### Quick Start: Branch-Based Triggers

Copy the two template files from `templates/` into YOUR repo's `.github/workflows/`:

```bash
# In YOUR repo:
cp dev-ci.yml .github/workflows/dev-ci.yml
cp staging-ci.yml .github/workflows/staging-ci.yml
```

#### `templates/dev-ci.yml` — Dev Branch (all checks except tests)

```yaml
name: Dev Branch CI

on:
  pull_request:
    branches: [dev]
  push:
    branches: [dev]

jobs:
  dev-checks:
    uses: blurgsai/ci-workflows-software-team/.github/workflows/dev-ci.yml@main
    secrets: inherit
```

This runs: backend coding standards, backend design pattern, frontend coding standards, frontend design pattern, frontend mock JSON, tileserver coding standards, tileserver design pattern, geoserver SRT pattern.

#### `templates/staging-ci.yml` — Staging Branch (tests only + source gate)

```yaml
name: Staging Branch CI

on:
  pull_request:
    branches: [staging]
  push:
    branches: [staging]

jobs:
  staging-checks:
    uses: blurgsai/ci-workflows-software-team/.github/workflows/staging-ci.yml@main
    secrets: inherit
```

This runs: source code change rejection gate → backend tests, frontend tests.
If any source files (`*.py`, `*.ts`, `*.tsx`, `*.js`, `*.jsx` under `src/`) are changed, the PR is rejected before tests run.

### Calling Individual Workflows

You can also call individual workflows directly if you need fine-grained control:

#### Backend Example

```yaml
jobs:
  coding-standards:
    uses: blurgsai/ci-workflows-software-team/.github/workflows/backend-coding-standards-check.yml@main
    secrets: inherit

  design-pattern:
    uses: blurgsai/ci-workflows-software-team/.github/workflows/backend-design-pattern-check.yml@main
    secrets: inherit

  tests:
    uses: blurgsai/ci-workflows-software-team/.github/workflows/backend-test-check.yml@main
    with:
      min-integration-tests: '5'
    secrets: inherit
```

#### Frontend Example

```yaml
jobs:
  coding-standards:
    uses: blurgsai/ci-workflows-software-team/.github/workflows/frontend-coding-standards-check.yml@main
    secrets: inherit

  design-pattern:
    uses: blurgsai/ci-workflows-software-team/.github/workflows/frontend-design-pattern-check.yml@main
    with:
      hooks-test-minimum: '50'
    secrets: inherit

  tests:
    uses: blurgsai/ci-workflows-software-team/.github/workflows/frontend-test-check.yml@main
    with:
      min-integration-tests: '10'
    secrets: inherit

  mock-json:
    uses: blurgsai/ci-workflows-software-team/.github/workflows/frontend-mock-json-check.yml@main
    secrets: inherit
```

#### Tileserver Example

```yaml
jobs:
  coding-standards:
    uses: blurgsai/ci-workflows-software-team/.github/workflows/tileserver-coding-standards-check.yml@main
    secrets: inherit

  design-pattern:
    uses: blurgsai/ci-workflows-software-team/.github/workflows/tileserver-design-pattern-check.yml@main
    secrets: inherit
```

#### GeoServer Example

```yaml
jobs:
  srt-pattern:
    uses: blurgsai/ci-workflows-software-team/.github/workflows/geoserver-srt-pattern-check.yml@main
    secrets: inherit
```

### Workflow Inputs

All workflows accept these optional inputs (defaults shown):

| Workflow | Input | Default | Description |
|----------|-------|---------|-------------|
| All | `ref` | `main` | Branch/ref of this shared CI repo |
| Dev CI | `backend-dir` | `backend` | Path to backend directory |
| Dev CI | `frontend-dir` | `frontend` | Path to frontend directory |
| Dev CI | `tileserver-dir` | `tileserver` | Path to tileserver directory |
| Dev CI | `geoserver-dir` | `geoserver` | Path to geoserver directory |
| Dev CI | `python-version` | `3.12` | Python version |
| Dev CI | `node-version` | `20` | Node.js version |
| Staging CI | `backend-dir` | `backend` | Path to backend directory |
| Staging CI | `frontend-dir` | `frontend` | Path to frontend directory |
| Staging CI | `python-version` | `3.12` | Python version |
| Staging CI | `node-version` | `20` | Node.js version |
| Staging CI | `min-integration-tests-frontend` | `10` | Min tests per frontend integration file |
| Staging CI | `min-integration-tests-backend` | `5` | Min test functions per backend integration file |
| Backend | `backend-dir` | `backend` | Path to backend directory |
| Backend | `python-version` | `3.12` | Python version |
| Backend Test | `min-integration-tests` | `5` | Min test functions per integration file |
| Frontend | `frontend-dir` | `frontend` | Path to frontend directory |
| Frontend | `node-version` | `20` | Node.js version |
| Frontend Design | `hooks-test-minimum` | `50` | Min tests per hook test file |
| Frontend Test | `min-integration-tests` | `10` | Min tests per integration file |
| Tileserver | `tileserver-dir` | `tileserver` | Path to tileserver directory |
| Tileserver | `python-version` | `3.12` | Python version |
| GeoServer | `geoserver-dir` | `geoserver` | Path to geoserver directory |

### Using the Shared ESLint Config

1. Install the package in your frontend:

```bash
npm install @software-team/eslint-config --registry=https://npm.pkg.github.com
```

2. Create `eslint.config.js` in your frontend:

```js
export { default } from '@software-team/eslint-config'
```

### Using the Python Linting Configs

Copy the relevant config files to your backend/tileserver:

```bash
# Backend
cp configs/python/backend-pyproject.toml backend/pyproject.toml
cp configs/python/backend-importlinter backend/.importlinter

# Tileserver
cp configs/python/tileserver-importlinter tileserver/.importlinter
```

## What Each Workflow Checks

### Backend

- **Coding Standards**: snake_case files, PascalCase classes, snake_case functions/variables, Ruff linter
- **Design Pattern**: src/ enforcement, feature folder structure (clients/models/services/router), no nested features, no top-level tech folders, layer import rules (Client → Model → Service → Router), barrel exports, services independent of FastAPI, router rules, import-linter boundaries, Ruff
- **Test Check**: integration test coverage (every router feature has tests), minimum test count, pytest run

### Frontend

- **Coding Standards**: file naming (PascalCase .tsx, camelCase .ts), hook naming (use* prefix), API file naming (*Api.ts), exported name conventions, ESLint, TypeScript type check
- **Design Pattern**: feature folder structure (api/model/hooks/ui), no nested features, no top-level tech folders, layer import rules (API → Model → Hooks → UI), barrel exports, hooks test placement, hooks single function per file, hooks test coverage, hooks test minimum
- **Mock JSON Check**: warns on static JSON fetches and localStorage usage (non-blocking)
- **Test Check**: integration test coverage, minimum test count, vitest run

### Tileserver

- **Coding Standards**: snake_case files, PascalCase classes, snake_case functions/variables, Ruff linter
- **Design Pattern**: src/ enforcement, feature folder structure (schemas/repository/services/router), no nested features, no top-level tech folders, layer import rules (Repository → Services → Router), barrel exports, services independent of FastAPI, router rules, import-linter boundaries, Ruff
- **Test Check**: (same as backend, run from tileserver context)

### GeoServer

- **SRT Pattern**: required files (docker-compose.yml, .env.example, .gitignore, README.md), executable scripts (start.sh, stop.sh), required directories (scripts/, config/), .gitignore patterns, no secrets in .env.example, docker-compose healthchecks, README sections, docker-compose syntax, shell script syntax, no hardcoded secrets
