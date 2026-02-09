#!/usr/bin/env sh

set -eu

usage() {
    cat <<'EOF'
Usage:
  worktree-add [branch]

Description:
  Adds a Git worktree for <branch> at:
    <absolute-common-git-dir>/../<branch>

  If branch is omitted, opens fzf with local/origin branches that are
  not already checked out in a worktree.

Behavior:
  - If local branch <branch> exists, use it.
  - Else if origin/<branch> exists, create local branch <branch> tracking origin/<branch>.
  - Else create a new local branch <branch> from current HEAD.
EOF
}

fatal() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ "$#" -gt 1 ]; then
    usage >&2
    exit 1
fi

common_gitdir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
if [ -z "$common_gitdir" ]; then
    common_gitdir="$(git rev-parse --git-common-dir 2>/dev/null || true)"
fi
if [ -z "$common_gitdir" ]; then
    fatal "Not inside a git repository."
fi

case "$common_gitdir" in
    /*) ;;
    *) common_gitdir="$(cd "$common_gitdir" 2>/dev/null && pwd -P)" ;;
esac

choose_branch() {
    if ! command -v fzf >/dev/null 2>&1; then
        fatal "fzf is required when no branch is provided."
    fi

    tmp_candidates="$(mktemp "${TMPDIR:-/tmp}/worktree-add-candidates.XXXXXX")"
    tmp_worktrees="$(mktemp "${TMPDIR:-/tmp}/worktree-add-worktrees.XXXXXX")"
    tmp_selectable="$(mktemp "${TMPDIR:-/tmp}/worktree-add-selectable.XXXXXX")"
    trap 'rm -f "$tmp_candidates" "$tmp_worktrees" "$tmp_selectable"' EXIT INT TERM

    {
        git for-each-ref --format='%(refname:short)' refs/heads
        git for-each-ref --format='%(refname:short)' refs/remotes/origin |
            sed -e '/^origin$/d' -e '/^origin\/HEAD$/d' -e 's#^origin/##'
    } | awk 'NF && !seen[$0]++' >"$tmp_candidates"

    if [ ! -s "$tmp_candidates" ]; then
        fatal "No local/origin branches found."
    fi

    git worktree list --porcelain | sed -n 's/^branch refs\/heads\///p' >"$tmp_worktrees"

    if [ -s "$tmp_worktrees" ]; then
        awk 'NR==FNR { used[$0]=1; next } !($0 in used)' "$tmp_worktrees" "$tmp_candidates" >"$tmp_selectable"
    else
        cp "$tmp_candidates" "$tmp_selectable"
    fi

    if [ ! -s "$tmp_selectable" ]; then
        fatal "No branches available (all known branches already have a worktree)."
    fi

    fzf --prompt='Branch> ' --height=40% --reverse <"$tmp_selectable"
}

if [ "$#" -eq 1 ]; then
    branch="$1"
else
    if branch="$(choose_branch)"; then
        [ -n "$branch" ] || exit 0
    else
        status=$?
        if [ "$status" -eq 130 ]; then
            exit 0
        fi
        exit "$status"
    fi
fi

worktree_path="$common_gitdir/../$branch"

if git show-ref --verify --quiet "refs/heads/$branch"; then
    git worktree add "$worktree_path" "$branch"
elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    git worktree add --track -b "$branch" "$worktree_path" "origin/$branch"
else
    git worktree add -b "$branch" "$worktree_path"
fi
