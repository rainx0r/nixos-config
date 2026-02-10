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
    tmp_branch_items="$tmp_dir/branch-items"
    tmp_pr_items="$tmp_dir/pr-items"
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

    tab_char="$(printf '\t')"
    awk -F "$tab_char" 'BEGIN { OFS="\t" } NF { print $1, $1 }' "$tmp_selectable" >"$tmp_branch_items"

    if git remote get-url origin >/dev/null 2>&1; then
        pr_remote="origin"
    else
        pr_remote="$(git remote | sed -n '1p')"
    fi

    : >"$tmp_pr_items"
    if [ -n "${pr_remote:-}" ]; then
        gh pr list --state open --limit 100 --json number,title --jq '.[] | "\(.number)\t\(.title)"' 2>/dev/null |
            while IFS="$tab_char" read -r pr_number pr_title; do
                [ -n "$pr_number" ] || continue
                printf '%s:%s\t#%s: %s\n' "$pr_remote" "$pr_number" "$pr_number" "$pr_title"
            done >"$tmp_pr_items"
    fi

    mode="branch"
    query=""
    while :; do
        if [ "$mode" = "branch" ]; then
            source_file="$tmp_branch_items"
            prompt='Branch> '
        else
            if [ ! -s "$tmp_pr_items" ]; then
                mode="branch"
                continue
            fi
            source_file="$tmp_pr_items"
            prompt='PR> '
        fi

        result="$(
            fzf --prompt="$prompt" --height=40% --reverse --expect=tab --print-query --query="$query" --delimiter="$tab_char" --with-nth=2 <"$source_file"
        )" || return $?

        query="$(printf '%s\n' "$result" | sed -n '1p')"
        key="$(printf '%s\n' "$result" | sed -n '2p')"
        selected="$(printf '%s\n' "$result" | sed -n '3p')"

        if [ "$key" = "tab" ]; then
            if [ "$mode" = "branch" ]; then
                mode="pr"
            else
                mode="branch"
            fi
            continue
        fi

        [ -n "$selected" ] || return 1
        printf '%s\n' "${selected%%"$tab_char"*}"
        return 0
    done
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
