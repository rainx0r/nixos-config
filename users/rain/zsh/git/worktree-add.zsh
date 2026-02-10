#!/usr/bin/env sh

set -eu

usage() {
    cat <<'EOF'
Usage:
  worktree-add [branch]
  worktree-add <remote>:<PR_NUMBER>

Description:
  Adds a Git worktree at:
    <absolute-common-git-dir>/../<target-name>

  Branch mode:
    target-name is <branch>.

  PR mode:
    target-name is pr-<PR_NUMBER>.
    Resolves the PR head branch with gh from the selected remote repo.

  If argument is omitted, opens fzf with local/remote branches that are
  not already checked out in a worktree.
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

common_gitdir="$(git rev-parse --path-format=absolute --git-common-dir)"
if [ -z "$common_gitdir" ]; then
    fatal "Not inside a git repository."
fi

choose_branch() {
    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/worktree-add.XXXXXX")"
    tmp_candidates="$tmp_dir/candidates"
    tmp_worktrees="$tmp_dir/worktrees"
    tmp_selectable="$tmp_dir/selectable"
    trap 'rm -rf "$tmp_dir"' EXIT INT TERM

    {
        git for-each-ref --format='%(refname:short)' refs/heads
        git for-each-ref --format='%(refname)' refs/remotes |
            sed -e '/\/HEAD$/d' -e 's#^refs/remotes/##'
    } | awk 'NF && !seen[$0]++' >"$tmp_candidates"

    if [ ! -s "$tmp_candidates" ]; then
        fatal "No local/remote branches found."
    fi

    git worktree list --porcelain | sed -n 's/^branch refs\/heads\///p' >"$tmp_worktrees"
    awk '
      NR==FNR { used[$0]=1; next }
      {
        name=$0
        sub("^[^/][^/]*/", "", name)  # strip remote if present
        if (!(name in used)) print $0
      }
    ' "$tmp_worktrees" "$tmp_candidates" >"$tmp_selectable"

    if [ ! -s "$tmp_selectable" ]; then
        fatal "No branches available (all known branches already have a worktree)."
    fi

    fzf --prompt='Branch> ' --height=40% --reverse <"$tmp_selectable"
}

start_point=""
remote=""
input="${1:-}"

if [ "$#" -eq 0 ]; then
    if input="$(choose_branch)"; then
        [ -n "$input" ] || exit 0
    else
        status=$?
        if [ "$status" -eq 130 ]; then
            exit 0
        fi
        exit "$status"
    fi
fi

case "$input" in
*:*)
    remote="${input%%:*}"
    pr="${input#*:}"
    case "$pr" in
      ''|*[!0-9]*) fatal "pr must be numeric: $pr" ;;
    esac

    pr_title="$(gh pr view "$pr" --json title -q .title)"
    slug="$(
      printf '%s' "$pr_title" |
        tr '[:upper:]' '[:lower:]' |
        tr -cs 'a-z0-9' '-' |
        sed 's/^-*//; s/-*$//' |
        cut -c1-48 |
        sed 's/-*$//'
    )"
    pr_ref="refs/remotes/$remote/pull/$pr"
    git fetch "$remote" "refs/pull/$pr/head:$pr_ref"

    start_point="$pr_ref"
    branch="pr-$pr${slug:+-$slug}"
    ;;
*/*)
    if git show-ref --verify --quiet "refs/heads/$input"; then
        branch="$input"
    else
        remote_candidate="${input%%/*}"
        if git remote get-url "$remote_candidate" >/dev/null 2>&1; then
            remote="$remote_candidate"
            branch="${input#*/}"
        else
            branch="$input"
        fi
    fi
    ;;
*)
    branch="$input"
    ;;
esac

# Validate branch name
git check-ref-format --branch "$branch" >/dev/null 2>&1 || fatal "Invalid branch name: $branch"

worktree_path="$common_gitdir/../${branch//\//-}"

if git show-ref --verify --quiet "refs/heads/$branch"; then
    # Local branch exists
    git worktree add "$worktree_path" "$branch"
elif [ -n "$start_point" ]; then
    # Branch is a PR
    git worktree add -b "$branch" "$worktree_path" "$start_point"
elif [ -n "$remote" ]; then
    # Branch was given as remote/branch
    git worktree add --track -b "$branch" "$worktree_path" "$remote/$branch"
else
    # Branch doesn't exist yet
    git worktree add -b "$branch" "$worktree_path"
fi
