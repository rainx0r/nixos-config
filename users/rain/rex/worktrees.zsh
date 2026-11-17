# Rex port of tmux-worktree-switcher: pick a git worktree of the repo the
# focused pane is in, and open it as a tab in the current session, reusing the
# tab if it's already open. Runs inside a floating pane opened by init.lua,
# started in the focused pane's working directory.
#
# Usage: zsh worktrees.zsh [CLIENT_ID]   (see popup-common.zsh)

source ${0:A:h}/popup-common.zsh

git rev-parse --git-common-dir >/dev/null 2>&1 || fail "not in a git repository ($PWD)"

worktrees=$(
    git worktree list --porcelain | awk '
        function flush() { if (path != "" && !bare) print branch "\t" path; path = "" }
        /^worktree / { flush(); path = substr($0, 10); branch = ""; bare = 0 }
        /^branch / { branch = substr($0, 8); sub("^refs/heads/", "", branch) }
        /^detached$/ { branch = "(detached)" }
        /^bare$/ { bare = 1 }
        END { flush() }
    '
)
[[ -n $worktrees ]] || fail "no worktrees"

tab=$'\t'
selected=$(
    paste <(echo "${worktrees//$tab$HOME/$tab~}" | column -t -s $tab) <(echo "$worktrees" | cut -f2) |
        fzf --delimiter $tab --with-nth 1 --padding 1 --reverse --prompt "Go to worktree> "
) || exit 0
dir=${selected##*$tab}
label=${dir:t}

# Worktrees of one repo are siblings with distinct names, so the tab label
# identifies the worktree's tab.
window=$(
    $rex window ls -s $REX_SESSION --json |
        jq -r --arg label $label 'first(.windows[] | select(.label == $label) | .window_id) // empty'
) || fail "couldn't list tabs"

if [[ -z $window ]]; then
    window=$($rex window new -s $REX_SESSION $label -c $dir --json | jq -er .window_id) ||
        fail "couldn't open $label"
fi
# Making the tab active on the server doesn't move the app, so ask it to.
show $REX_SESSION $window
