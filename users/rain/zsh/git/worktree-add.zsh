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

  If argument is omitted, opens fzf with local/origin branches that are
  not already checked out in a worktree.
EOF
}

fatal() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

require_command() {
    command -v "$1" >/dev/null 2>&1 || fatal "$2"
}

resolve_common_gitdir() {
    gitdir="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null || true)"
    if [ -z "$gitdir" ]; then
        gitdir="$(git rev-parse --git-common-dir 2>/dev/null || true)"
    fi
    [ -n "$gitdir" ] || return 1

    case "$gitdir" in
    /*) ;;
    *)
        gitdir="$(cd "$gitdir" 2>/dev/null && pwd -P)" || return 1
        ;;
    esac

    printf '%s\n' "$gitdir"
}

validate_branch_name() {
    git check-ref-format --branch "$1" >/dev/null 2>&1 || fatal "Invalid branch name: $1"
}

remote_to_repo() {
    remote_name="$1"
    remote_url="$(git remote get-url "$remote_name" 2>/dev/null || true)"
    [ -n "$remote_url" ] || fatal "Remote '$remote_name' does not exist."

    case "$remote_url" in
    git@*:*)
        host_path="${remote_url#*@}"
        host="${host_path%%:*}"
        repo_path="${host_path#*:}"
        ;;
    ssh://* | http://* | https://* | git://*)
        without_scheme="${remote_url#*://}"
        without_user="${without_scheme#*@}"
        host="${without_user%%/*}"
        repo_path="${without_user#*/}"
        ;;
    */*)
        host="github.com"
        repo_path="$remote_url"
        ;;
    *)
        fatal "Cannot parse remote URL for '$remote_name': $remote_url"
        ;;
    esac

    repo_path="${repo_path%/}"
    repo_path="${repo_path%.git}"
    owner="${repo_path%%/*}"
    repo_name="${repo_path#*/}"

    if [ -z "$owner" ] || [ -z "$repo_name" ] || [ "$owner" = "$repo_name" ] || [ "${repo_name#*/}" != "$repo_name" ]; then
        fatal "Cannot parse owner/repo from remote URL for '$remote_name': $remote_url"
    fi

    if [ "$host" = "github.com" ]; then
        printf '%s/%s\n' "$owner" "$repo_name"
    else
        printf '%s/%s/%s\n' "$host" "$owner" "$repo_name"
    fi
}

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
    usage
    exit 0
fi

if [ "$#" -gt 1 ]; then
    usage >&2
    exit 1
fi

common_gitdir="$(resolve_common_gitdir || true)"
if [ -z "$common_gitdir" ]; then
    fatal "Not inside a git repository."
fi

choose_branch() {
    require_command fzf "fzf is required when no branch is provided."

    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/worktree-add.XXXXXX")"
    tmp_candidates="$tmp_dir/candidates"
    tmp_worktrees="$tmp_dir/worktrees"
    tmp_selectable="$tmp_dir/selectable"
    trap 'rm -rf "$tmp_dir"' EXIT INT TERM

    {
        git for-each-ref --format='%(refname:short)' refs/heads
        git for-each-ref --format='%(refname:short)' refs/remotes/origin |
            sed -e '/^origin$/d' -e '/^origin\/HEAD$/d' -e 's#^origin/##'
    } | awk 'NF && !seen[$0]++' >"$tmp_candidates"

    if [ ! -s "$tmp_candidates" ]; then
        fatal "No local/origin branches found."
    fi

    git worktree list --porcelain | sed -n 's/^branch refs\/heads\///p' >"$tmp_worktrees"
    awk 'NR==FNR { used[$0]=1; next } !($0 in used)' "$tmp_worktrees" "$tmp_candidates" >"$tmp_selectable"

    if [ ! -s "$tmp_selectable" ]; then
        fatal "No branches available (all known branches already have a worktree)."
    fi

    fzf --prompt='Branch> ' --height=40% --reverse <"$tmp_selectable"
}

start_point=""

if [ "$#" -eq 1 ]; then
    input="$1"

    case "$input" in
    *:*)
        remote="${input%%:*}"
        pr_number="${input#*:}"

        [ -n "$remote" ] || fatal "Expected <remote>:<PR_NUMBER>."
        [ -n "$pr_number" ] || fatal "Expected <remote>:<PR_NUMBER>."

        case "$pr_number" in
        *[!0-9]*) fatal "PR number must be numeric in <remote>:<PR_NUMBER>." ;;
        esac

        require_command gh "gh is required for PR mode."

        repo_spec="$(remote_to_repo "$remote")"
        if ! head_branch="$(gh pr view "$pr_number" --repo "$repo_spec" --json headRefName -q .headRefName)"; then
            fatal "Failed to resolve PR #$pr_number in $repo_spec."
        fi
        [ -n "$head_branch" ] || fatal "PR #$pr_number in $repo_spec has no head branch."

        if git show-ref --verify --quiet "refs/remotes/$remote/$head_branch"; then
            start_point="$remote/$head_branch"
        else
            pull_ref="refs/remotes/$remote/pull/$pr_number/head"
            if git fetch "$remote" "+refs/pull/$pr_number/head:$pull_ref"; then
                start_point="$remote/pull/$pr_number/head"
            else
                fatal "Remote branch '$remote/$head_branch' not found, and failed to fetch refs/pull/$pr_number/head from '$remote'."
            fi
        fi

        branch="pr-$pr_number"
        ;;
    *)
        branch="$input"
        ;;
    esac
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

validate_branch_name "$branch"

worktree_path="$common_gitdir/../$branch"

if git show-ref --verify --quiet "refs/heads/$branch"; then
    git worktree add "$worktree_path" "$branch"
elif [ -n "$start_point" ]; then
    git worktree add --track -b "$branch" "$worktree_path" "$start_point"
elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
    git worktree add --track -b "$branch" "$worktree_path" "origin/$branch"
else
    git worktree add -b "$branch" "$worktree_path"
fi
