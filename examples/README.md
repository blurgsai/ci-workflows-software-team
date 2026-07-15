# Example caller workflows for each repo

Copy these files into your repo's `.github/workflows/` directory and adjust as needed.

## Branch Strategy

- **PR to `dev`** → runs coding standards + design pattern checks (no tests)
- **PR to `staging`** → runs only tests, and only triggers when `tests/` or `__tests__/` files change
