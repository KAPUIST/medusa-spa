---
description: Git auto-commit rules for AI development
alwaysApply: true
---

# AI Git Auto-Commit Rules

## Overview

AI automatically executes git commits whenever code modifications are completed. This ensures consistent version control and clear development history.

## When to Auto-Commit

### Commit Triggers

1. **After completing a feature or task**
2. **After fixing a bug**
3. **After refactoring code**
4. **After updating documentation**
5. **After making configuration changes**

### Do NOT Commit When

- Build is failing
- Tests are failing
- Lint errors exist
- Work is incomplete or in progress
- Debugging temporary code exists

## Commit Message Format

Follow **Conventional Commits** specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Commit Types

| Type       | Description                                           | Example                                    |
| ---------- | ----------------------------------------------------- | ------------------------------------------ |
| `feat`     | New feature                                           | `feat(api): add order export endpoint`     |
| `fix`      | Bug fix                                               | `fix(cart): resolve quantity update issue` |
| `refactor` | Code refactoring                                      | `refactor(auth): simplify JWT validation`  |
| `docs`     | Documentation changes                                 | `docs(api): update endpoint documentation` |
| `style`    | Code style changes (formatting, semicolons, etc.)     | `style(ui): format button component`       |
| `test`     | Adding or updating tests                              | `test(orders): add integration tests`      |
| `chore`    | Build process or auxiliary tool changes               | `chore(deps): update medusa to v2.0`       |
| `perf`     | Performance improvements                              | `perf(db): optimize order query`           |
| `ci`       | CI configuration changes                              | `ci(github): add deployment workflow`      |
| `build`    | Build system changes                                  | `build(docker): update postgres image`     |
| `revert`   | Revert previous commit                                | `revert: feat(api): add order export`      |

### Scope Guidelines

Scope indicates the area of the codebase affected:

- `api` - API endpoints
- `db` - Database changes
- `auth` - Authentication/authorization
- `cart` - Shopping cart functionality
- `order` - Order management
- `product` - Product management
- `ui` - UI components
- `config` - Configuration
- `workflow` - Medusa workflows
- `subscriber` - Event subscribers
- `job` - Background jobs

### Subject Guidelines

- Use imperative mood ("add" not "added" or "adds")
- Don't capitalize first letter
- No period at the end
- Limit to 50 characters
- Be specific and descriptive

### Examples

#### Good Commit Messages

```bash
# Feature addition
feat(api): add bulk product import endpoint

# Bug fix
fix(checkout): resolve payment processing timeout issue

# Refactoring
refactor(order): extract validation logic to separate service

# Documentation
docs(readme): add docker setup instructions

# Style changes
style(api): apply prettier formatting to route handlers

# Test addition
test(product): add unit tests for price calculation

# Chore
chore(deps): upgrade @medusajs/medusa to v2.1.0

# Performance
perf(db): add index to order_date column

# With body
feat(api): add order status webhook

Implement webhook endpoint to notify external systems
when order status changes. Supports configurable retry
logic and authentication.

Closes #123
```

#### Bad Commit Messages

```bash
# ❌ Too vague
fix: bug fix

# ❌ Not imperative
feat: added new feature

# ❌ Capitalized
Fix: Bug in cart

# ❌ Period at end
feat: add feature.

# ❌ Too long
feat: add a new feature that allows users to export their order history in CSV format with filters

# ❌ No type
add order export
```

## Auto-Commit Workflow

### Step 1: Verify Code Quality

Before committing, ensure:

```bash
# 1. Build succeeds
yarn build

# 2. Linting passes
yarn lint

# 3. Type checking passes
yarn check-types

# 4. Tests pass (if applicable)
yarn test
```

### Step 2: Stage Changes

```bash
# Stage all changes
git add .

# Or stage specific files
git add apps/server/src/api/routes/orders.ts
git add apps/server/src/services/order-service.ts
```

### Step 3: Create Commit

```bash
# Use conventional commit format
git commit -m "feat(api): add order export endpoint"
```

### Step 4: Verify Commit

```bash
# Check commit was created
git log -1 --oneline

# Check git status
git status
```

## Pre-Commit Checklist

Before executing git commit, verify:

- [ ] All TypeScript errors resolved
- [ ] Build completes successfully (`yarn build`)
- [ ] Linting passes (`yarn lint`)
- [ ] No console.log or debug code left
- [ ] Tests pass (if tests exist)
- [ ] No sensitive information (API keys, passwords)
- [ ] No large binary files or unnecessary files
- [ ] .env files are not staged
- [ ] node_modules is not staged
- [ ] Commit message follows conventional format

## Files to NEVER Commit

Ensure these are in `.gitignore`:

```
# Dependencies
node_modules/
.yarn/
.pnp.*

# Environment files
.env
.env.local
.env.*.local

# Build outputs
dist/
build/
.turbo/
.medusa/

# Logs
*.log
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Temporary files
tmp/
temp/
*.tmp
```

## Multi-Change Commits

### Separate Unrelated Changes

```bash
# ❌ Bad - Multiple unrelated changes in one commit
git add .
git commit -m "feat: add features and fix bugs"

# ✅ Good - Separate commits for separate changes
git add apps/server/src/api/routes/orders.ts
git commit -m "feat(api): add order export endpoint"

git add apps/server/src/services/payment-service.ts
git commit -m "fix(payment): resolve timeout issue"
```

### Group Related Changes

```bash
# ✅ Good - Group related files in one commit
git add apps/server/src/api/routes/orders.ts
git add apps/server/src/services/order-service.ts
git add apps/server/src/types/order.ts
git commit -m "feat(order): add order cancellation feature"
```

## Breaking Changes

For breaking changes, add `BREAKING CHANGE:` in commit body:

```bash
git commit -m "feat(api): change order status enum

BREAKING CHANGE: Order status values changed from
uppercase to lowercase. Update all API clients.

Old: 'PENDING', 'COMPLETED'
New: 'pending', 'completed'"
```

## Co-Authoring

For pair programming or collaboration:

```bash
git commit -m "feat(api): add order webhook

Co-authored-by: John Doe <john@example.com>"
```

**IMPORTANT**: Never include AI assistant references (Claude, Cursor, etc.) in commit messages or co-author tags.

## Commit Frequency

### Good Practice

- Commit after completing each logical unit of work
- Commit when switching between different tasks
- Commit before major refactoring
- Commit after resolving merge conflicts

### Avoid

- Committing every single line change
- Large commits with 100+ file changes
- Commits with "WIP" or "temp" messages
- Committing broken code

## Git Commands Reference

```bash
# View recent commits
git log --oneline -10

# View current status
git status

# View staged changes
git diff --staged

# Unstage files
git reset HEAD <file>

# Amend last commit (if not pushed)
git commit --amend -m "new message"

# View commit history
git log --graph --oneline --all
```

## Important Notes

1. **Always verify build before commit**: Run `yarn build` to ensure no build errors
2. **Check lint**: Run `yarn lint` to ensure code style compliance
3. **Review changes**: Use `git diff` to review what will be committed
4. **Meaningful messages**: Write descriptive commit messages that explain WHY, not just WHAT
5. **Small commits**: Prefer small, focused commits over large, complex ones
6. **No secrets**: Never commit sensitive information
7. **Test before commit**: Ensure tests pass if they exist
8. **Follow conventions**: Always use conventional commit format

## Automation Script Example

```bash
#!/bin/bash
# scripts/auto-commit.sh

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo "🔍 Running pre-commit checks..."

# Check build
echo "📦 Building..."
if ! yarn build; then
  echo -e "${RED}❌ Build failed. Please fix errors before committing.${NC}"
  exit 1
fi

# Check lint
echo "🔍 Linting..."
if ! yarn lint; then
  echo -e "${RED}❌ Lint failed. Please fix errors before committing.${NC}"
  exit 1
fi

echo -e "${GREEN}✅ All checks passed!${NC}"
echo "📝 Ready to commit."
```

## Emergency Rollback

If you need to undo the last commit:

```bash
# Undo commit but keep changes
git reset --soft HEAD~1

# Undo commit and discard changes (DANGEROUS!)
git reset --hard HEAD~1
```
