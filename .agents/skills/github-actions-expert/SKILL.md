---
name: github-actions-expert
description: Expert guidance for creating secure, scalable, and efficient GitHub Actions workflows. Enforces security best practices and enterprise-grade patterns.
license: MIT
---

## What I do
- Author complete GitHub Actions workflows (`.github/workflows/*.yml`).
- Audit existing workflows for security vulnerabilities (injection, excessive permissions).
- Optimize CI/CD pipelines for speed (caching) and maintainability (reusable workflows).
- Implement secure secret management patterns.

## When to use me
- When creating CI/CD pipelines (test, build, deploy).
- When automating repository tasks (labeling, releasing).
- When asked to "fix github actions" or "secure the pipeline".
- Triggers: "create workflow", "github action", "ci pipeline".

## Instructions

### 1. Security First (Non-Negotiable)
- **Permissions**: ALWAYS define `permissions: {}` at the top level and grant specific permissions at the job level.
  ```yaml
  permissions:
    contents: read # Default to read-only
  ```
- **Script Injection**: NEVER interpolate untrusted input directly into shell scripts.
  - BAD: `run: echo "Title: ${{ github.event.issue.title }}"`
  - GOOD:
    ```yaml
    env:
      TITLE: ${{ github.event.issue.title }}
    run: echo "Title: $TITLE"
    ```
- **Secrets**: NEVER hardcode secrets. Use `${{ secrets.MY_SECRET }}`.
- **Pinning**: Recommend pinning actions to a specific commit SHA, not a tag, for high-security environments.
  - `uses: actions/checkout@a5ac7e51b41094c92402da3b24376905380afc29 # v4.1.6`

### 2. Operational Excellence
- **Concurrency**: Use `concurrency` groups to cancel outdated runs on PRs.
  ```yaml
  concurrency:
    group: ${{ github.workflow }}-${{ github.ref }}
    cancel-in-progress: true
  ```
- **Timeouts**: ALWAYS set a `timeout-minutes` for jobs to prevent stuck runners costing money/time.
- **Caching**: Use `actions/cache` or language-specific setup actions (e.g., `setup-node` with `cache: 'npm'`) to speed up builds.

### 3. Architecture Patterns
- **Reusable Workflows**: Extract common logic (setup, linting) into `common.yml` to adhere to DRY (Don't Repeat Yourself).
- **Matrix Builds**: Use strategy matrices for testing multiple versions/OSs efficiently.
- **Fail Fast**: Default `fail-fast: true` in matrices, but consider `false` if you want full coverage reports despite failures.

### 4. Anti-Patterns to Avoid
- **`pull_request_target` Abuse**: Be extremely careful. Never checkout and run code from a fork with write permissions.
- **Inline Scripts**: For scripts > 5 lines, create a separate `.sh` or `.py` file in the repo and call it. This makes it testable and lintable.
- **Blind Updates**: Don't use `@latest` or `@master`. It breaks builds unexpectedly.

### 5. Example "Senior" Workflow Snippet
```yaml
name: CI
on:
  pull_request:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  test:
    runs-on: ubuntu-latest
    timeout-minutes: 10
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
      - run: npm ci
      - run: npm test
```
