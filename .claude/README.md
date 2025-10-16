# Cursor Rules Documentation

This directory contains Cursor IDE rules for AI-assisted development in the spa-medusa-monorepo project.

## Overview

Cursor Rules help AI assistants understand project conventions, coding standards, and workflows. These rules are automatically applied when working with Cursor IDE.

## File Structure

```
.claude/
├── README.md                    # This file
├── 00-base-rules.md            # Base coding rules and conventions
├── 01-git-auto-commit.md       # Git commit automation rules
├── 02-github-pr.md             # GitHub PR automation rules
└── PR_BODY_TEMPLATE.md         # Template for PR descriptions
```

## Rule Files

### 00-base-rules.md

**Always Applied**: Yes
**Purpose**: Core coding standards and best practices

Contains:
- Project structure and naming conventions
- TypeScript configuration and type safety rules
- Error handling patterns
- Performance optimization guidelines
- Testing strategies
- Security best practices
- Code quality standards

### 01-git-auto-commit.md

**Always Applied**: Yes
**Purpose**: Automated git commit workflow

Contains:
- When to create commits
- Conventional commit format rules
- Commit message examples
- Pre-commit verification checklist
- Files to never commit
- Multi-change commit strategies

### 02-github-pr.md

**Always Applied**: No (manual trigger)
**Purpose**: GitHub Pull Request automation

Contains:
- PR creation workflow
- PR title and body formatting
- Label conventions
- Review process guidelines
- PR templates for different types of changes

## How to Use

### For AI Assistants (Cursor)

Cursor automatically reads and applies rules marked with `alwaysApply: true`. Rules are applied based on file globs and context.

### For Developers

#### Creating Commits

When AI completes a task, it will automatically:

1. Verify build and lint pass
2. Stage appropriate files
3. Create commit with conventional format
4. Show commit summary

Example:
```bash
✅ Build passed
✅ Lint passed
📝 Creating commit: feat(api): add order export endpoint
✅ Commit created successfully
```

#### Creating Pull Requests

To create a PR, ask the AI:

```
"Create a PR for this feature"
```

The AI will:

1. Show a dry-run plan
2. Ask for approval
3. Create/update PR with appropriate metadata
4. Return PR URL

Example output:
```
[DRY-RUN] PR Operation Plan
----------------------------
Base Branch: main
Title: feat(api): add order export endpoint
Labels: feature, api
Reviewers: alice, bob

Proceed? (yes/no)
```

## Customizing Rules

### Adding New Rules

1. Create a new file: `.claude/03-your-rule.md`
2. Add frontmatter:
```yaml
---
description: Your rule description
globs: "**/*.ts"
alwaysApply: true
---
```
3. Write rule content in markdown

### Modifying Existing Rules

Edit the relevant `.md` file. Changes take effect immediately in Cursor.

### Rule Priority

Rules are applied in order:
1. Files with lower numbers first (00, 01, 02, ...)
2. More specific globs override general ones
3. Later rules can override earlier rules

## Conventional Commit Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(api): add webhook support` |
| `fix` | Bug fix | `fix(auth): resolve token expiry issue` |
| `refactor` | Code refactoring | `refactor(db): simplify query logic` |
| `docs` | Documentation | `docs(readme): update setup instructions` |
| `style` | Code formatting | `style: apply prettier formatting` |
| `test` | Test changes | `test(order): add integration tests` |
| `chore` | Build/config | `chore(deps): update dependencies` |
| `perf` | Performance | `perf(api): optimize product query` |

## PR Labels

### Type Labels
- `feature` - New functionality
- `bugfix` - Bug fix
- `enhancement` - Improvement
- `refactor` - Code refactoring
- `docs` - Documentation
- `test` - Tests

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
- `infrastructure` - Infrastructure
- `security` - Security-related

## Scripts

### cursor-create-pr.sh

Located in `scripts/cursor-create-pr.sh`, this script automates PR creation.

**Usage:**
```bash
bash scripts/cursor-create-pr.sh \
  --base main \
  --title "feat(api): add feature" \
  --body-file .claude/PR_BODY_TEMPLATE.md \
  --labels "feature,api" \
  --reviewers "alice,bob"
```

**Options:**
- `--base <branch>` - Target base branch
- `--title "<text>"` - PR title (required)
- `--body "<text>"` - PR body text
- `--body-file <path>` - PR body from file
- `--draft` - Create as draft
- `--reviewers "u1,u2"` - Reviewers
- `--assignees "u1,u2"` - Assignees
- `--labels "l1,l2"` - Labels
- `--update-if-exists` - Update existing PR
- `--dry-run` - Show plan without executing

## Best Practices

### Commit Frequency

✅ **Do:**
- Commit after completing a logical unit of work
- Commit before switching tasks
- Commit before major refactoring

❌ **Don't:**
- Commit broken code
- Commit work in progress without tests
- Create huge commits with 100+ files

### PR Size

✅ **Do:**
- Keep PRs small (< 400 lines)
- One feature/fix per PR
- Break large changes into multiple PRs

❌ **Don't:**
- Mix multiple unrelated changes
- Create PRs with 1000+ line changes
- Include refactoring with feature changes

### Code Review

✅ **Do:**
- Self-review before requesting review
- Respond to all comments
- Test changes thoroughly
- Update documentation

❌ **Don't:**
- Rush through reviews
- Ignore reviewer feedback
- Merge without approval
- Skip testing

## Prerequisites

### Required Tools

1. **Git**: Version control
   ```bash
   git --version
   ```

2. **GitHub CLI**: PR automation
   ```bash
   gh --version
   gh auth login
   ```

3. **Node.js**: Runtime (v18+)
   ```bash
   node --version
   ```

4. **Yarn**: Package manager
   ```bash
   yarn --version
   ```

### Environment Setup

1. Clone repository
2. Install dependencies: `yarn install`
3. Setup environment: Copy `.env.template` to `.env`
4. Login to GitHub CLI: `gh auth login`

## Troubleshooting

### Build Fails Before Commit

```bash
# Check build errors
yarn build

# Fix TypeScript errors
yarn check-types

# Fix linting issues
yarn lint --fix
```

### PR Creation Fails

```bash
# Check GitHub CLI authentication
gh auth status

# Check current branch
git branch

# Check remote
git remote -v

# Push branch first
git push -u origin <branch-name>
```

### Commit Rejected by Hook

If pre-commit hooks fail:

```bash
# Fix the issues
yarn lint --fix
yarn check-types

# Try commit again
git commit -m "your message"
```

## FAQ

### Q: Can I commit without AI?

Yes, you can create commits manually:
```bash
git add .
git commit -m "feat(api): your message"
```

### Q: Can I create PRs without the script?

Yes, use GitHub CLI directly:
```bash
gh pr create --base main --title "feat: your title"
```

### Q: How do I disable auto-commits?

Set `alwaysApply: false` in `01-git-auto-commit.md` frontmatter.

### Q: Can I use different commit formats?

You can, but conventional commits are strongly recommended for consistency.

### Q: What if I need to break the rules?

Rules are guidelines, not strict requirements. Use your judgment, but document why you're deviating.

## Contributing

To improve these rules:

1. Create a feature branch
2. Modify rule files
3. Test with Cursor IDE
4. Create PR with changes
5. Request review from team

## Resources

- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub CLI Documentation](https://cli.github.com/manual/)
- [Cursor IDE Documentation](https://cursor.sh/docs)
- [TypeScript Best Practices](https://www.typescriptlang.org/docs/handbook/declaration-files/do-s-and-don-ts.html)

## Version History

- **v1.0.0** (2025-10-16): Initial cursor rules setup
  - Base coding standards
  - Git auto-commit workflow
  - GitHub PR automation
  - PR templates

## Support

For issues or questions:

1. Check this README
2. Review specific rule file documentation
3. Ask team members
4. Create an issue in the repository

---

**Last Updated**: 2025-10-16
**Maintained By**: Development Team
