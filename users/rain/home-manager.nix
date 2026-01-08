{
  config,
  lib,
  pkgs,
  inputs,
  pkgs-unstable,
  ...
}:

let
  isDarwin = pkgs.stdenv.isDarwin;
in
{
  home.stateVersion = "24.11";

  home.packages =
    with pkgs;
    [
      # vcs
      git
      git-crypt
      gh
      ghq
      jujutsu
      lazygit
      lazyjj

      # python
      python3
      pkgs-unstable.uv

      # rust
      rustc
      cargo
      rustfmt

      # js
      nodejs
      pnpm

      # devops
      lazydocker
      terraform
      cloudflared

      # misc
      bat
      lsd
      ripgrep
      fastfetch

      # typesetting
      pkgs-unstable.typst

      # llm clis
      pkgs-unstable.claude-code
      pkgs-unstable.codex
      pkgs-unstable.gemini-cli
      pkgs-unstable.opencode
    ]
    ++ (lib.optionals isDarwin [
      cmake
    ]);

  home.sessionVariables = {
    LANG = "en_GB.UTF-8";
    LC_CTYPE = "en_GB.UTF-8";
    LC_ALL = "en_GB.UTF-8";
    EDITOR = "nvim";
    PAGER = "less -FirSwX";
    NIX = if !isDarwin then "1" else "";
    RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
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
      plugins = [
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
      saveNoDups = true;
      findNoDups = true;
      append = true;
      share = true;
    };

    shellAliases = {
      ls = "lsd";
      lt = "ls --tree";
      l = "ls -l";
      lla = "ls -la";
      la = "ls -a";
      cat = "bat --paging=never";
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

    initContent = ''
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

      # home-manager session vars in every shell including tmux panes
      . "/etc/profiles/per-user/$USER/etc/profile.d/hm-session-vars.sh"

      # Custom
      source ${config.xdg.configHome}/zsh/widgets.zsh
      source ${config.xdg.configHome}/zsh/p10k.zsh
      unset ZSH_AUTOSUGGEST_USE_ASYNC  # Needed to fix p10k x OMZP::git
    '';
  };

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
      "bg+" = "16";
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
    settings = {
      branch.autosetuprebase = "always";
      color.ui = true;
      credential.helper = "store";
      github.user = "rainx0r";
      push.default = "tracking";
      push.recurseSubmodules = "on-demand";
      init.defaultBranch = "main";
      ghq.root = "~/Repositories";
      status.submoduleSummary = true;
      diff.submodule = "log";
      submodule.recurse = true;
      fetch.recurseSubmodules = "on-demand";
      user = {
        name = "rain";
        email = "evan@latent.dev";
      };
    };
  };

  programs.jujutsu = {
    enable = true;
    settings = {
      user = {
        name = "rainx0r";
        email = "evan@latent.dev";
      };
    };
  };

  programs.btop = {
    enable = true;
    settings = {
      color_theme = "rainx0r";
      vim_keys = true;
    };
  };

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

      # https://github.com/nix-community/home-manager/issues/5952
      set -gu default-command
      set -g default-shell "$SHELL"
    '';
  };

  xdg.configFile = {
    "fastfetch" = {
      source = ./fastfetch;
      recursive = true;
    };
    "zsh/widgets.zsh".source = if isDarwin then ./zsh/widgets-darwin.zsh else ./zsh/widgets.zsh;
    "zsh/p10k.zsh".source = ./zsh/p10k.zsh;
    "btop/themes/rainx0r.theme".text = builtins.readFile ./themes/btop;
    "nvim" = {
      source = inputs.nvim-config-rain;
      recursive = true;
    };
    "zed" = {
      source = ./zed;
      recursive = true;
    };
    "nixpkgs" = {
      # Needed for nix-shell to use unfree packages
      source = ./nixpkgs;
      recursive = true;
    };
    "uv" = {
      source = ./uv;
      recursive = true;
    };
  }
  // (
    if isDarwin then
      {
        "karabiner/karabiner.json".source = ./karabiner/karabiner.json;
        "ghostty" = {
          source = ./ghostty;
          recursive = true;
        };
        "safari.css".source = ./safari.css;
      }
    else
      { }
  );

  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
    extraPackages = with pkgs-unstable; [
      # lsps
      lua-language-server
      bash-language-server
      stylua
      nixd
      nixfmt-rfc-style
      ty
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
      vscode-langservers-extracted
      tinymist
      typstyle

      # deps
      tree-sitter
      nodejs
      gnumake
      gcc
      luarocks # lazy
      packer # terraform
    ];
  };

  programs = {
    direnv = {
      enable = true;
      enableZshIntegration = true;
      nix-direnv = {
        enable = true;
        package = pkgs-unstable.nix-direnv;
      };
    };
  };
}
