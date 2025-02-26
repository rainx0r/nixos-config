function tmux-sessionizer {
    # Yoinked and edited from the tmuxagen https://github.com/ThePrimeagen/.dotfiles/blob/master/tmux/.tmux.conf
    # Unfathomably based workflow
    github_repos="$HOME/Repositories/github.com"
    experiments="$HOME/Experiments"
    selected=$(
        find $github_repos $experiments -type d \( -path "$github_repos/*" -depth 2 -prune \) -o \( -path "$experiments/*" -depth 1 -prune \) ! -name ".DS_Store" \
        | sed "s|$github_repos|github|g" | sed "s|$experiments|experiments|g"\
        | fzf --margin 5% --tmux 80% --reverse --border --border-label "Go to project"
    )

    if [[ -z $selected ]]; then
        return
    fi

    selected="${selected//github/$github_repos}"
    selected="${selected//experiments/$experiments}"

    selected_name=$(basename "$selected" | tr . _)
    tmux_running=$(pgrep tmux)

    if  [[ -z $tmux_running ]] || ! tmux has-session -t=$selected_name 2> /dev/null; then
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

