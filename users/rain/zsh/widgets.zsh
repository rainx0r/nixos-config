function tmux-sessionizer {
    # Yoinked and edited from the tmuxagen https://github.com/ThePrimeagen/.dotfiles/blob/master/tmux/.tmux.conf
    github_repos="$HOME/Repositories/github.com"
    experiments="$HOME/Experiments"
    selected=$(
        (
            find $github_repos -type d -mindepth 2 -maxdepth 2
            find $experiments -type d -mindepth 1 -maxdepth 1
        ) |
            sed "s|$github_repos|github|g" | sed "s|$experiments|experiments|g" |
            fzf --padding 1 --tmux center,100%,100% --reverse --border --border-label "Go to project"
    )

    if [[ -z $selected ]]; then
        return
    fi

    selected="${selected//github/$github_repos}"
    selected="${selected//experiments/$experiments}"

    selected_name=$(basename "$selected" | tr . _)
    tmux_running=$(pgrep tmux)

    if [[ -z $tmux_running ]] || ! tmux has-session -t=$selected_name 2>/dev/null; then
        tmux new-session -ds $selected_name -c $selected
    fi

    (
        exec </dev/tty
        exec <&1
        if [[ -z $TMUX ]]; then
            tmux attach -t $selected_name
        else
            tmux switch-client -t $selected_name
        fi
    )
}
autoload -U tmux-sessionizer
zle -N tmux-sessionizer

function tmux-worktree-switcher {
    common_gitdir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)
    worktrees=$(
        [[ -n $common_gitdir ]] && git worktree list --porcelain | awk '
            function flush() { if (path != "" && !bare) print branch "\t" path; path = "" }
            /^worktree / { flush(); path = substr($0, 10); branch = ""; bare = 0 }
            /^branch / { branch = substr($0, 8); sub("^refs/heads/", "", branch) }
            /^detached$/ { branch = "(detached)" }
            /^bare$/ { bare = 1 }
            END { flush() }
        '
    )

    if [[ -z $worktrees ]]; then
        if [[ -n $TMUX ]]; then
            tmux display-message "No worktrees"
        elif zle; then
            zle -M "No worktrees"
        else
            echo "No worktrees"
        fi
        return
    fi

    tab=$'\t'
    selected=$(
        paste <(echo "${worktrees//$tab$HOME/$tab~}" | column -t -s $tab) <(echo "$worktrees" | cut -f2) |
            fzf --delimiter $'\t' --with-nth 1 --padding 1 --tmux center,100%,100% --reverse --border --border-label "Go to worktree"
    )

    if [[ -z $selected ]]; then
        return
    fi

    selected=$(echo "$selected" | cut -f2)

    if [[ -n $TMUX ]]; then
        # Open the worktree as a window in the current session, reusing it if it's already open
        window=$(
            tmux list-windows -F "#{window_id}$tab#{@worktree}" |
                awk -F "$tab" -v path="$selected" '$2 == path { print $1; exit }'
        )
        if [[ -z $window ]]; then
            window=$(tmux new-window -P -F "#{window_id}" -n "$(basename "$selected")" -c "$selected")
            tmux set-option -w -t "$window" @worktree "$selected"
        fi
        tmux select-window -t "$window"
        return
    fi

    # Same name as tmux-sessionizer for the main worktree, <project>/<worktree> otherwise
    project_dir=$(dirname "$common_gitdir")
    selected_name=$(basename "$project_dir")
    if [[ $selected != $project_dir ]]; then
        selected_name="$selected_name/$(basename "$selected")"
    fi
    selected_name=$(echo "$selected_name" | tr . _)

    if ! tmux has-session -t=$selected_name 2>/dev/null; then
        tmux new-session -ds $selected_name -c $selected
    fi

    (
        exec </dev/tty
        exec <&1
        tmux attach -t $selected_name
    )
}
autoload -U tmux-worktree-switcher
zle -N tmux-worktree-switcher
