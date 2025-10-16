#!/usr/bin/env bash
# cursor-create-pr.sh
# Create or update a GitHub Pull Request for the current branch.
# Requires: git, gh (GitHub CLI) logged in: `gh auth login`
#
# Typical usage (Cursor generates title/body for review then calls):
#   bash scripts/cursor-create-pr.sh \
#     --base main \
#     --title "feat: add POS report API" \
#     --body-file /tmp/cursor_pr_body.md \
#     --labels "feature,backend" \
#     --reviewers "alice,bob"
#
# Long body can also be piped:
#   echo "## Changes\n- ..." | bash scripts/cursor-create-pr.sh --title "feat: ..." --base main
#
# Options:
#   --base <branch>            : PR base branch (default: origin's default branch)
#   --title "<text>"           : PR title (required)
#   --title-file <path>        : Read title from file (lower priority than title)
#   --body "<markdown>"        : PR body text
#   --body-file <path>         : PR body file path (lower priority than body)
#   --draft                    : Create as draft PR
#   --reviewers "u1,u2"        : Comma-separated reviewers
#   --assignees "u1,u2"        : Comma-separated assignees
#   --labels "l1,l2"           : Comma-separated labels
#   --update-if-exists         : Update existing PR instead of failing
#   --dry-run                  : Show execution plan without actually creating/updating
#   -h | --help                : Show help message
#
# Behavior:
# 1) Check current git branch → push to origin (set upstream)
# 2) Check if PR exists for same head branch
#    - If not: gh pr create
#    - If yes: stop by default, or with --update-if-exists use gh pr edit to update title/body/labels/assignees/reviewers
# 3) Output created/updated PR URL

set -euo pipefail

# --- helpers ---
err() { echo "::error:: $*" 1>&2; }
die() { err "$@"; exit 1; }
has_cmd() { command -v "$1" >/dev/null 2>&1; }

BASE_BRANCH=""
TITLE=""
TITLE_FILE=""
BODY=""
BODY_FILE=""
IS_DRAFT="false"
REVIEWERS=""
ASSIGNEES=""
LABELS=""
UPDATE_IF_EXISTS="false"
DRY_RUN="false"

# parse args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE_BRANCH="$2"; shift 2;;
    --title) TITLE="$2"; shift 2;;
    --title-file) TITLE_FILE="$2"; shift 2;;
    --body) BODY="$2"; shift 2;;
    --body-file) BODY_FILE="$2"; shift 2;;
    --draft) IS_DRAFT="true"; shift 1;;
    --reviewers) REVIEWERS="$2"; shift 2;;
    --assignees) ASSIGNEES="$2"; shift 2;;
    --labels) LABELS="$2"; shift 2;;
    --update-if-exists) UPDATE_IF_EXISTS="true"; shift 1;;
    --dry-run) DRY_RUN="true"; shift 1;;
    -h|--help)
      sed -n '1,80p' "$0" || true
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
  esac
done

# prerequisites
has_cmd git || die "git not found"
has_cmd gh  || die "gh (GitHub CLI) not found. Install: https://cli.github.com/"

# ensure in a git repo
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || die "Not inside a git repository."

# current branch
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
[[ "$CURRENT_BRANCH" != "HEAD" ]] || die "You are in detached HEAD. Checkout a branch."

# find default base if not provided
if [[ -z "$BASE_BRANCH" ]]; then
  # Try to derive origin default branch
  if git rev-parse --abbrev-ref --symbolic-full-name "origin/HEAD" >/dev/null 2>&1; then
    BASE_BRANCH="$(git rev-parse --abbrev-ref --symbolic-full-name origin/HEAD | sed 's#^origin/##')"
  else
    BASE_BRANCH="main"
  fi
fi

# gather title
if [[ -z "$TITLE" ]]; then
  if [[ -n "$TITLE_FILE" ]]; then
    [[ -f "$TITLE_FILE" ]] || die "Title file not found: $TITLE_FILE"
    TITLE="$(head -n1 "$TITLE_FILE" | tr -d '\r')"
  fi
fi
[[ -n "$TITLE" ]] || die "--title or --title-file is required."

# gather body -> temp file (gh prefers --body or --body-file; we'll prefer file for long content)
TMP_BODY_FILE=""
cleanup() { [[ -n "${TMP_BODY_FILE:-}" && -f "$TMP_BODY_FILE" ]] && rm -f "$TMP_BODY_FILE"; }
trap cleanup EXIT

if [[ -n "$BODY" ]]; then
  TMP_BODY_FILE="$(mktemp -t pr_body.XXXXXX)"
  printf "%s\n" "$BODY" > "$TMP_BODY_FILE"
elif [[ -n "$BODY_FILE" ]]; then
  [[ -f "$BODY_FILE" ]] || die "Body file not found: $BODY_FILE"
  TMP_BODY_FILE="$BODY_FILE"
elif [ -p /dev/stdin ]; then
  TMP_BODY_FILE="$(mktemp -t pr_body.XXXXXX)"
  cat - > "$TMP_BODY_FILE"
else
  # default minimal body
  TMP_BODY_FILE="$(mktemp -t pr_body.XXXXXX)"
  printf "PR for branch \`%s\`\n" "$CURRENT_BRANCH" > "$TMP_BODY_FILE"
fi

# push current branch
if [[ "$DRY_RUN" == "true" ]]; then
  echo "[DRY-RUN] Would push branch: $CURRENT_BRANCH -> origin"
else
  git push -u origin "$CURRENT_BRANCH"
fi

# check if PR exists for this branch
PR_EXISTS="false"
if gh pr view "$CURRENT_BRANCH" >/dev/null 2>&1; then
  PR_EXISTS="true"
fi

# build common flags
CREATE_FLAGS=( --base "$BASE_BRANCH" --head "$CURRENT_BRANCH" --title "$TITLE" )
EDIT_FLAGS=( --title "$TITLE" )
[[ "$IS_DRAFT" == "true" ]] && CREATE_FLAGS+=( --draft )

if [[ -n "$TMP_BODY_FILE" ]]; then
  CREATE_FLAGS+=( --body-file "$TMP_BODY_FILE" )
  EDIT_FLAGS+=( --body-file "$TMP_BODY_FILE" )
fi

if [[ -n "$LABELS" ]]; then
  CREATE_FLAGS+=( --label "$LABELS" )
  # gh pr edit supports multiple --add-label flags; pass as one comma list too.
  IFS=',' read -ra _LABS <<< "$LABELS"
  for L in "${_LABS[@]}"; do EDIT_FLAGS+=( --add-label "$(echo "$L" | xargs)" ); done
fi

if [[ -n "$ASSIGNEES" ]]; then
  CREATE_FLAGS+=( --assignee "$ASSIGNEES" )
  IFS=',' read -ra _ASG <<< "$ASSIGNEES"
  for A in "${_ASG[@]}"; do EDIT_FLAGS+=( --add-assignee "$(echo "$A" | xargs)" ); done
fi

if [[ -n "$REVIEWERS" ]]; then
  CREATE_FLAGS+=( --reviewer "$REVIEWERS" )
  # gh pr edit also supports --add-reviewer
  IFS=',' read -ra _RVS <<< "$REVIEWERS"
  for R in "${_RVS[@]}"; do EDIT_FLAGS+=( --add-reviewer "$(echo "$R" | xargs)" ); done
fi

# dry-run output
if [[ "$DRY_RUN" == "true" ]]; then
  echo "============================================"
  echo "        DRY-RUN: PR Operation Plan"
  echo "============================================"
  echo ""
  echo "Repository Info:"
  echo "  Current Branch : $CURRENT_BRANCH"
  echo "  Base Branch    : $BASE_BRANCH"
  echo ""
  echo "PR Details:"
  echo "  Title          : $TITLE"
  echo "  Body Source    : ${BODY_FILE:-${BODY:+inline text}}"
  echo "  Draft          : $IS_DRAFT"
  echo ""
  [[ -n "$LABELS" ]] && echo "  Labels         : $LABELS"
  [[ -n "$REVIEWERS" ]] && echo "  Reviewers      : $REVIEWERS"
  [[ -n "$ASSIGNEES" ]] && echo "  Assignees      : $ASSIGNEES"
  echo ""

  if [[ "$PR_EXISTS" == "false" ]]; then
    echo "Action: CREATE new PR"
    echo "Command: gh pr create ${CREATE_FLAGS[*]}"
  else
    if [[ "$UPDATE_IF_EXISTS" == "true" ]]; then
      echo "Action: UPDATE existing PR"
      echo "Command: gh pr edit $CURRENT_BRANCH ${EDIT_FLAGS[*]}"
    else
      echo "Action: FAIL (PR exists, --update-if-exists not specified)"
    fi
  fi
  echo ""
  echo "============================================"
  exit 0
fi

# act
if [[ "$PR_EXISTS" == "false" ]]; then
  echo "Creating PR to $BASE_BRANCH from $CURRENT_BRANCH ..."
  gh pr create "${CREATE_FLAGS[@]}"
else
  if [[ "$UPDATE_IF_EXISTS" == "true" ]]; then
    echo "Existing PR found. Updating..."
    gh pr edit "$CURRENT_BRANCH" "${EDIT_FLAGS[@]}"
  else
    die "PR already exists for branch '$CURRENT_BRANCH'. Use --update-if-exists to edit it."
  fi
fi

# print final URL
if gh pr view "$CURRENT_BRANCH" --json url,number >/dev/null 2>&1; then
  # Avoid requiring jq; use -q for simple JSON queries if available
  URL="$(gh pr view "$CURRENT_BRANCH" --json url -q .url 2>/dev/null || true)"
  NUM="$(gh pr view "$CURRENT_BRANCH" --json number -q .number 2>/dev/null || true)"
  [[ -n "$URL" ]] && echo "✅ PR #${NUM:-?}: $URL"
fi
