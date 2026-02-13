set -euo pipefail

usage() {
    cat <<'EOF'
Usage:
  github-clone OWNER/REPO

Description:
  Clones a GitHub repository as a bare repo into:
    <root>/github.com/OWNER/REPO

  where root comes from:
    git config ghq.root

  The clone is configured so remote-tracking refs exist under
  refs/remotes/origin/* (worktree-friendly), then fetched once.

Examples:
  git config --global ghq.root "$HOME/Repositories"
  github-clone rainx0r/nixos-config
EOF
}

fatal() {
    printf 'Error: %s\n' "$*" >&2
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 1
fi

spec="$1"

if [[ ! "$spec" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
    fatal "Expected OWNER/REPO (example: rainx0r/nixos-config)."
fi

owner="${spec%%/*}"
repo="${spec#*/}"

root="${ROOT_DIR:-$(git config --get ghq.root || true)}"
if [[ -z "$root" ]]; then
    fatal "Missing root directory. Set git config ghq.root."
fi

if [[ "$root" == "~"* ]]; then
    root="${root/#\~/$HOME}"
fi

if [[ "$root" != /* ]]; then
    root="$(pwd)/$root"
fi

target="$root/github.com/$owner/$repo"
target_bare="$target/.bare"
url="https://github.com/$owner/$repo.git"

if [[ -e "$target" ]]; then
    fatal "Target path already exists: $target"
fi

mkdir -p "$target"

printf 'Cloning %s\n' "$url"
git clone --bare -c remote.origin.fetch=+refs/heads/*:refs/remotes/origin/* "$url" "$target_bare"
echo "gitdir: $target_bare" >"$target/.git"
git -C "$target" fetch origin --prune

default_ref="$(git -C "$target" symbolic-ref --short refs/remotes/origin/HEAD)"
default_branch="${default_ref#origin/}"
worktree_path="$target/$default_branch"
git -C "$target" worktree add "$worktree_path" "$default_branch"
git -C "$target" branch --set-upstream-to="$default_ref" "$default_branch" >/dev/null
