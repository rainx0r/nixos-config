# Rex port of tmux-sessionizer: pick a project, create its session if needed,
# then switch the Rex app to it. Runs inside a floating pane opened by init.lua.
#
# Usage: zsh sessionizer.zsh

# Commands in a pane don't read ~/.zshrc, so the PATH fix there doesn't apply.
rex=${REX_BIN_DIR:+$REX_BIN_DIR/}rex
# The app has a different client ID on each host, so find it on this server:
# the app attached to the session this pane is in.
client=$(
    $rex client ls -s $REX_SESSION --json 2>/dev/null |
        jq -r '[.clients[] | select(.info.kind == "app")][0].client_id // empty'
)
github_repos=$HOME/Repositories/github.com
experiments=$HOME/Experiments

fail() {
    print -u2 "sessionizer: $*"
    read -sk '?Press any key to close'
    exit 1
}

# A new floating pane starts at 80x24 and gets its real size ~100ms later.
# Wait for that (up to 300ms) so fzf doesn't draw at 24 rows and then jump.
for i in {1..30}; do
    [[ $(stty size </dev/tty) != "24 80" ]] && break
    sleep 0.01
done

selected=$(
    {
        find $github_repos -mindepth 2 -maxdepth 2 -type d
        find $experiments -mindepth 1 -maxdepth 1 -type d
    } 2>/dev/null |
        sed -e "s|^$github_repos/|github/|" -e "s|^$experiments/|experiments/|" |
        fzf --padding 1 --reverse --prompt "Go to project> "
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
