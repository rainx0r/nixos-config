{ inputs, ... }:

{
  config,
  lib,
  pkgs,
  ...
}:

let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  home.stateVersion = "24.11";

  home.packages = with pkgs; [
    git
    python3
    uv
    bat
    lsd
    gh
    ghq
    ripgrep
    fastfetch
    lazygit
    terraform
  ];

  home.sessionVariables = with pkgs; {
    LANG = "en_GB.UTF-8";
    LC_CTYPE = "en_GB.UTF-8";
    PC_ALL = "en_GB.UTF-8";
    EDITOR = "nvim";
    PAGER = "less -FirSwX";
    NIX = if !isDarwin then "1" else null;
    NIX_LD_LIBRARY_PATH =
      if !isDarwin then
        lib.makeLibraryPath [
          stdenv.cc.cc
          zlib
          addDriverRunpath.driverLink
        ]
      else
        null;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion = {
      enable = true;
      highlight = "fg=243";
    };
    syntaxHighlighting.enable = true;
    defaultKeymap = "viins";

    antidote = {
      enable = true;
      plugins =
        [
          "Aloxaf/fzf-tab"
          "romkatv/powerlevel10k"
          "getantidote/use-omz"
          "ohmyzsh/ohmyzsh path:plugins/git"
          "ohmyzsh/ohmyzsh path:plugins/sudo"
          "ohmyzsh/ohmyzsh path:plugins/command-not-found"
          "ohmyzsh/ohmyzsh path:plugins/python"
          "ohmyzsh/ohmyzsh path:plugins/docker"
          "ohmyzsh/ohmyzsh path:plugins/docker-compose"
        ]
        ++ (lib.optionals isDarwin [
          "ohmyzsh/ohmyzsh path:plugins/macos"
          "ohmyzsh/ohmyzsh path:plugins/xcode"
        ]);
    };

    history = {
      save = 5000;
      ignoreAllDups = true;
      # TODO: enable when 25.05 comes out
      # saveNoDups = true;
      # findNoDups = true;
      append = true;
      share = true;
    };

    shellAliases =
      {
        ls = "lsd";
        lt = "ls --tree";
        l = "ls -l";
        lla = "ls -la";
        la = "ls -a";
        cat = "bat --paging=never";
        vim = "nvim";
      }
      // (
        if isDarwin then
          {
            colab-runtime-local = "ssh workstation-local -L 9000:localhost:9000";
            colab-runtime-remote = "ssh workstation -L 9000:localhost:9000";
          }
        else
          { }
      );

    initExtra = ''
      bindkey '^p' history-search-backward
      bindkey '^n' history-search-forward
      bindkey '^f' autosuggest-accept
      bindkey '^g' tmux-sessionizer

      # fzf-tab
      zstyle ':fzf-tab:*' fzf-flags $(echo $FZF_DEFAULT_OPTS)
      zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
      zstyle ':completion:*' list-colors $LS_COLORS
      zstyle ':completion:*' menu no
      zstyle ':completion:*:git-checkout:*' sort false
      zstyle ':fzf-tab:*' fzf-command ftb-tmux-popup
      zstyle ':fzf-tab:complete:cd:*' fzf-preview 'lsd --color always $realpath'

      # nix-ld
      . "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"

      # Custom
      source ${config.xdg.configHome}/zsh/widgets.zsh
      source ${config.xdg.configHome}/zsh/p10k.zsh
      unset ZSH_AUTOSUGGEST_USE_ASYNC  # Needed to fix p10k x OMZP::git
    '';
  };
  xdg.configFile."zsh/widgets.zsh".source =
    if isDarwin then ./zsh/widgets-darwin.zsh else ./zsh/widgets.zsh;
  xdg.configFile."zsh/p10k.zsh".source = ./zsh/p10k.zsh;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    colors = {
      pointer = "2";
      hl = "6";
      "hl+" = "14";
      border = "12";
      label = "3";
      prompt = "4";
      "bg+" = "17";
    };
    defaultOptions = [ "-e" ];
  };

  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
    options = [ "--cmd cd" ];
  };

  programs.git = {
    enable = true;
    userName = "rain";
    userEmail = "angel@latent.dev";
    extraConfig = {
      branch.autosetuprebase = "always";
      color.ui = true;
      credential.helper = "store";
      github.user = "rainx0r";
      push.default = "tracking";
      init.defaultBranch = "main";
      ghq.root = "~/Repositories";
    };
  };

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "rainx0r";
      vim_keys = true;
    };
  };
  xdg.configFile."btop/themes/rainx0r.theme".text = builtins.readFile ./themes/btop;

  programs.tmux = {
    enable = true;
    mouse = true;
    baseIndex = 1;
    aggressiveResize = true;
    escapeTime = 0;
    plugins = with pkgs; [
      tmuxPlugins.vim-tmux-navigator
      tmuxPlugins.sensible
      tmuxPlugins.yank
    ];
    extraConfig = ''
      set-option -g renumber-windows on
      set-option -g repeat-time 1000

      bind '"' split-window -v -c "#{pane_current_path}"
      bind % split-window -h -c "#{pane_current_path}"
      bind g run-shell "zsh -c 'source ${config.xdg.configHome}/zsh/widgets.zsh ; tmux-sessionizer'"

      # Styling
      set -g status-left '''
      setw -g status-left ""
      setw -g status-left-style fg=green,bg=default
      setw -g status-style fg=green,bg=default
      set -g status-right ''' 
      setw -g status-right " %H:%M #h "
      setw -g status-right-style fg=green,bg=default
      setw -g window-status-current-format " #{bold}#{window_index}:#{window_name}"
      setw -g window-status-current-style fg=4,bg=default
      setw -g window-status-format " #{window_index}:#{window_name}"
      setw -g window-status-style fg=colour250,bg=default
      set -g pane-border-style fg=colour239,bg=default
      set -g pane-active-border-style fg=colour15,bg=default
    '';
  };

  xdg.configFile = {
    "fastfetch/config.jsonc".text = builtins.readFile ./fastfetch/config.jsonc;
    "fastfetch/logo.png".source = ./fastfetch/logo.png;
  };

  programs.neovim = {
    enable = true;
    extraPackages = with pkgs; [
      # lsps
      lua-language-server
      stylua
      nixd
      nixfmt-rfc-style
      basedpyright
      ruff
      taplo
      rust-analyzer
      haskell-language-server
      zls
      markdownlint-cli
      clang-tools
      shfmt
      shellcheck
      terraform-ls
      nodePackages.vscode-json-languageserver

      # deps
      tree-sitter
      nodejs
      gnumake
      gcc
    ];
  };
  xdg.configFile."nvim" = {
    source = inputs.nvim-config-rain;
    recursive = true;
  };
}
