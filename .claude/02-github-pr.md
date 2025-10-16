---
description: GitHub Pull Request automation rules
alwaysApply: false
---

# GitHub PR Rules

## Overview

Automatically create or update GitHub Pull Requests when requested by the user. This rule provides a streamlined workflow for PR management.

**CRITICAL**: Never include AI assistant references (Claude, Cursor, AI, etc.) in PR titles, bodies, or commit messages.

## Prerequisites

Before using this rule, ensure:

1. **GitHub CLI installed**: `gh` command available
2. **Authenticated**: Run `gh auth login`
3. **Git repository**: Working in a valid git repository
4. **Remote configured**: Origin remote pointing to GitHub

## When to Use

Trigger PR creation when:

- User explicitly requests "create PR"
- User types "@cursor-create-pr"
- Feature development is complete
- Bug fix is ready for review
- Documentation updates are done

## Do NOT Create PR When

- Code has build errors
- Tests are failing
- Lint errors exist
- Work is incomplete
- Branch is not pushed to remote

## PR Creation Workflow

### Step 1: Pre-PR Checklist

Before creating PR, verify:

```bash
# 1. Build succeeds
yarn build

# 2. Linting passes
yarn lint

# 3. Type checking passes
yarn check-types

# 4. All changes are committed
git status

# 5. Branch is pushed
git push -u origin <branch-name>
```

### Step 2: Gather PR Information

Collect the following information:

- **Base branch**: Target branch (default: `main` or repository default)
- **Title**: Clear, descriptive title following conventional commits
- **Body**: Detailed description of changes
- **Labels**: Relevant labels (feature, bugfix, etc.)
- **Reviewers**: Team members to review
- **Assignees**: People responsible for the PR

### Step 3: Generate PR Content

#### Title Format

Follow conventional commit format:

```
<type>(<scope>): <description>
```

Examples:

```
feat(api): add order export endpoint
fix(checkout): resolve payment timeout issue
docs(readme): update installation instructions
refactor(service): simplify order validation logic
```

**IMPORTANT**: Do NOT include any AI-related text in PR titles.

#### Body Template

Use this template for PR body:

```markdown
## Summary

Brief description of what this PR does.

## Changes

- Bullet point list of main changes
- Another change
- Third change

## Type of Change

- [ ] New feature (non-breaking change which adds functionality)
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update
- [ ] Refactoring (no functional changes)
- [ ] Performance improvement
- [ ] Test addition/update

## Testing

- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing completed
- [ ] All tests passing

## Checklist

- [ ] Code follows project style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings generated
- [ ] Tests added/updated
- [ ] Build succeeds
- [ ] Lint passes

## Related Issues

Closes #issue-number

## Screenshots (if applicable)

Add screenshots or GIFs for UI changes.

## Additional Notes

Any additional information reviewers should know.
```

**IMPORTANT**: Do NOT include AI assistant footers, signatures, or references in PR body.

### Step 4: Dry-Run Confirmation

Always show a dry-run plan before creating PR:

```bash
bash scripts/cursor-create-pr.sh \
  --dry-run \
  --base main \
  --title "feat(api): add order export endpoint" \
  --body-file /tmp/pr-body.md \
  --labels "feature,backend" \
  --reviewers "reviewer1,reviewer2"
```

Output should show:

```
[DRY-RUN] PR Creation Plan:
- Base Branch: main
- Head Branch: feature/order-export
- Title: feat(api): add order export endpoint
- Body: From /tmp/pr-body.md
- Labels: feature, backend
- Reviewers: reviewer1, reviewer2
- Mode: CREATE (no existing PR found)

Proceed? (yes/no):
```

### Step 5: User Approval

Wait for explicit user approval:

- ✅ Proceed if user says: "yes", "approve", "ok", "proceed"
- ❌ Stop if user says: "no", "cancel", "stop", "wait"

### Step 6: Execute PR Creation

After approval, execute the command:

```bash
bash scripts/cursor-create-pr.sh \
  --update-if-exists \
  --base main \
  --title "feat(api): add order export endpoint" \
  --body-file /tmp/pr-body.md \
  --labels "feature,backend" \
  --reviewers "reviewer1,reviewer2"
```

## Script Usage

### Basic Usage

```bash
# Create PR with default settings
bash scripts/cursor-create-pr.sh \
  --title "feat: add new feature" \
  --body-file .claude/PR_BODY_TEMPLATE.md

# Create PR with specific base branch
bash scripts/cursor-create-pr.sh \
  --base develop \
  --title "fix: resolve bug" \
  --body "Bug fix description"

# Create draft PR
bash scripts/cursor-create-pr.sh \
  --draft \
  --title "wip: work in progress" \
  --body-file /tmp/pr-body.md
```

### Advanced Usage

```bash
# PR with labels, reviewers, and assignees
bash scripts/cursor-create-pr.sh \
  --base main \
  --title "feat(api): add webhook support" \
  --body-file .claude/PR_BODY_TEMPLATE.md \
  --labels "feature,api,high-priority" \
  --reviewers "alice,bob" \
  --assignees "charlie"

# Update existing PR
bash scripts/cursor-create-pr.sh \
  --update-if-exists \
  --title "feat(api): add webhook support (updated)" \
  --body "Updated description with more details"
```

### Script Options

| Option                | Description                               | Example                           |
| --------------------- | ----------------------------------------- | --------------------------------- |
| `--base <branch>`     | Target base branch                        | `--base main`                     |
| `--title "<text>"`    | PR title (required)                       | `--title "feat: add feature"`     |
| `--title-file <path>` | Read title from file                      | `--title-file /tmp/title.txt`     |
| `--body "<text>"`     | PR body content                           | `--body "Description"`            |
| `--body-file <path>`  | Read body from file                       | `--body-file PR_BODY_TEMPLATE.md` |
| `--draft`             | Create as draft PR                        | `--draft`                         |
| `--reviewers "u1,u2"` | Comma-separated reviewers                 | `--reviewers "alice,bob"`         |
| `--assignees "u1,u2"` | Comma-separated assignees                 | `--assignees "charlie"`           |
| `--labels "l1,l2"`    | Comma-separated labels                    | `--labels "feature,api"`          |
| `--update-if-exists`  | Update existing PR instead of failing     | `--update-if-exists`              |
| `--dry-run`           | Show plan without executing               | `--dry-run`                       |
| `-h, --help`          | Show help message                         | `--help`                          |

## PR Labels

Use consistent labels for easy filtering:

### Type Labels

- `feature` - New feature
- `bugfix` - Bug fix
- `enhancement` - Improvement to existing feature
- `refactor` - Code refactoring
- `docs` - Documentation changes
- `test` - Test additions/updates
- `chore` - Maintenance tasks

### Priority Labels

- `critical` - Critical priority
- `high-priority` - High priority
- `medium-priority` - Medium priority
- `low-priority` - Low priority

### Area Labels

- `frontend` - Frontend changes
- `backend` - Backend changes
- `api` - API changes
- `database` - Database changes
- `infrastructure` - Infrastructure changes
- `security` - Security-related changes

### Status Labels

- `wip` - Work in progress
- `ready-for-review` - Ready for review
- `needs-testing` - Needs testing
- `blocked` - Blocked by something

## Error Handling

### Common Errors and Solutions

#### 1. gh not installed

```
Error: gh (GitHub CLI) not found
Solution: Install from https://cli.github.com/
```

#### 2. Not authenticated

```
Error: Not logged into GitHub
Solution: Run 'gh auth login'
```

#### 3. PR already exists

```
Error: PR already exists for branch
Solution: Use --update-if-exists flag
```

#### 4. Branch not pushed

```
Error: Branch not found on remote
Solution: Run 'git push -u origin <branch>'
```

#### 5. Detached HEAD

```
Error: You are in detached HEAD
Solution: Checkout a branch: 'git checkout -b <branch>'
```

## Best Practices

### PR Title Best Practices

- Use conventional commit format
- Be specific and descriptive
- Limit to 50-72 characters
- Start with lowercase (except proper nouns)
- No period at the end
- **Never include AI assistant references**

#### Good Examples

```
feat(api): add bulk order import endpoint
fix(checkout): resolve payment gateway timeout
docs(readme): add docker compose setup guide
refactor(service): simplify authentication logic
perf(db): optimize product query with indexes
```

#### Bad Examples

```
Update code                    # Too vague
feat: Added new feature.       # Wrong tense, has period
FIX: Bug in cart              # All caps, too vague
add order export feature that allows... # Too long
feat: add feature (by AI)     # Contains AI reference
```

### PR Body Best Practices

1. **Start with summary**: Brief overview of changes
2. **List main changes**: Bullet points for clarity
3. **Explain why**: Context and reasoning
4. **Testing notes**: How to test the changes
5. **Screenshots**: For UI changes
6. **Breaking changes**: Highlight if applicable
7. **Related issues**: Link to issues
8. **Never add AI footers**: No "Generated by Claude/Cursor/AI" text

### PR Size Best Practices

- Keep PRs small and focused (< 400 lines changed)
- One feature or fix per PR
- Break large changes into multiple PRs
- Use draft PRs for work in progress

### Review Process

1. **Self-review first**: Review your own changes
2. **Run tests**: Ensure all tests pass
3. **Check CI**: Wait for CI to complete
4. **Address feedback**: Respond to all comments
5. **Keep updated**: Rebase or merge latest base branch

## PR Templates

### Feature PR Template

```markdown
## Feature Description

[Describe the new feature]

## Implementation Details

- [Key implementation point 1]
- [Key implementation point 2]

## Testing

- [ ] Unit tests added
- [ ] Integration tests added
- [ ] Manual testing completed

## Documentation

- [ ] README updated
- [ ] API docs updated
- [ ] Code comments added

Closes #[issue-number]
```

### Bug Fix PR Template

```markdown
## Bug Description

[Describe the bug that was fixed]

## Root Cause

[Explain what was causing the bug]

## Solution

[Explain how the bug was fixed]

## Testing

- [ ] Reproduced the bug before fix
- [ ] Verified fix resolves the issue
- [ ] Added regression tests

Fixes #[issue-number]
```

### Refactor PR Template

```markdown
## Refactoring Goals

[What you're trying to improve]

## Changes Made

- [Change 1]
- [Change 2]

## Why This Change?

[Explain the benefits]

## Testing

- [ ] All existing tests pass
- [ ] No functionality changes
- [ ] Performance verified

## Backwards Compatibility

[Any breaking changes or migration needed]
```

## Security Considerations

### Never Include in PR

- API keys or secrets
- Passwords or tokens
- Private keys
- Environment-specific configurations
- Large binary files
- node_modules or build artifacts
- AI assistant attribution

### Review Before Creating

- Check git diff for sensitive data
- Verify .env files are not staged
- Ensure no debug code is committed
- Check for hardcoded credentials
- Remove any AI-generated footers or signatures

## Monitoring and Metrics

Track these metrics for PR health:

- PR creation to merge time
- Number of review iterations
- Test pass rate
- CI build time
- Code review turnaround time

## GitHub Actions Integration

PRs should trigger:

1. **Lint checks**: ESLint, Prettier
2. **Type checks**: TypeScript compiler
3. **Unit tests**: Jest tests
4. **Integration tests**: E2E tests
5. **Build verification**: Production build
6. **Security scans**: Dependency audits

## Rollback Process

If a PR needs to be reverted:

```bash
# Find the merge commit
git log --oneline --merges

# Revert the merge commit
git revert -m 1 <merge-commit-sha>

# Push the revert
git push origin main

# Create a new PR for the revert
bash scripts/cursor-create-pr.sh \
  --title "revert: feat(api): add order export" \
  --body "Reverting #123 due to production issues"
```

## Important Reminders

1. **No AI references**: Never include Claude, Cursor, AI, or assistant mentions in PR titles or bodies
2. **No AI footers**: Do not add "Generated by", "Created with", or similar AI attribution
3. **No Co-authored-by AI**: Only use Co-authored-by for human collaborators
4. **Professional tone**: PRs should appear as if written entirely by the development team
