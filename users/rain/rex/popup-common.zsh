# Shared setup for the popup scripts (sessionizer.zsh, worktrees.zsh), sourced
# with the script's arguments.
#
# Sets $rex, the rex command, and $client, the app to switch: the ID the key
# binding passed as $1 (the app that pressed the key). That ID only means
# something on the server that ran the binding. When it isn't a client here,
# prefer an app connected over ssh (someone viewing this host remotely) over
# the app running on this machine, then any app.

# Commands in a pane don't read ~/.zshrc, so the PATH fix there doesn't apply.
rex=${REX_BIN_DIR:+$REX_BIN_DIR/}rex

clients=$($rex client ls -s $REX_SESSION --json 2>/dev/null)
client=$1
if [[ -z $client ]] || ! jq -e --arg id $client 'any(.clients[]; .client_id == $id)' <<<$clients >/dev/null; then
    client=
    apps=$(jq -r '.clients[] | select(.info.kind == "app") | "\(.client_id) \(.principal.pid // "")"' <<<$clients)
    while read -r id pid; do
        [[ -n $pid && $(ps -o comm= -p $pid 2>/dev/null) == sshd* ]] && { client=$id; break; }
    done <<<$apps
    [[ -z $client ]] && client=${${(f)apps}[1]%% *}
fi

fail() {
    print -u2 "${ZSH_ARGZERO:t:r}: $*"
    read -sk '?Press any key to close'
    exit 1
}

# Show $1 (session ID) and optionally tab $2 (window ID) in the app.
show() {
    $rex ${client:+-C} $client do session.select session_id=$1 ${2:+window_id=$2} >/dev/null ||
        fail "couldn't switch the app (is Remote Control on in Settings > Server?)"
}

# A new floating pane starts at 80x24 and gets its real size ~100ms later.
# Wait for that (up to 300ms) so fzf doesn't draw at 24 rows and then jump.
for i in {1..30}; do
    [[ $(stty size </dev/tty) != "24 80" ]] && break
    sleep 0.01
done
