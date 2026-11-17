# Rex port of tmux-sessionizer: pick a project, create its session if needed,
# then switch the Rex app to it. Runs inside a floating pane opened by init.lua.
#
# Usage: zsh sessionizer.zsh CLIENT_ID

client=$1
# Commands in a pane don't read ~/.zshrc, so the PATH fix there doesn't apply.
rex=${REX_BIN_DIR:+$REX_BIN_DIR/}rex
github_repos=$HOME/Repositories/github.com
experiments=$HOME/Experiments

fail() {
    print -u2 "sessionizer: $*"
    read -sk '?Press any key to close'
    exit 1
}

selected=$(
    {
        find $github_repos -mindepth 2 -maxdepth 2 -type d
        find $experiments -mindepth 1 -maxdepth 1 -type d
    } 2>/dev/null |
        sed -e "s|^$github_repos/|github/|" -e "s|^$experiments/|experiments/|" |
        fzf --padding 1 --reverse --border --border-label "Go to project"
) || exit 0

case $selected in
    github/*) dir=$github_repos/${selected#github/} ;;
    experiments/*) dir=$experiments/${selected#experiments/} ;;
    *) exit 0 ;;
esac
name=${dir:t}

session=$(
    $rex session ls --json |
        jq -r --arg label $name '.sessions[] | select(.label == $label) | .session_id' |
        head -n 1
) || fail "couldn't list sessions"

if [[ -z $session ]]; then
    session=$($rex new $name -c $dir --json | jq -er .session_id) ||
        fail "couldn't create session $name"
fi

$rex ${client:+-C} $client do session.select session_id=$session ||
    fail "couldn't switch to $name (is Remote Control on in Settings > Server?)"
