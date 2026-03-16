{ pkgs, pkgs-unstable, ... }:

{
  system = {
    stateVersion = 5;
    primaryUser = "rain";

    defaults = {
      NSGlobalDomain = {
        KeyRepeat = 2; # 120, 90, 60, 30, 12, 6, 2
        InitialKeyRepeat = 15; # 120, 94, 68, 35, 25, 15
      };
      CustomUserPreferences = {
        "com.microsoft.VSCode" = {
          ApplePressAndHoldEnabled = false;
        };
        "com.microsoft.VSCodeInsiders" = {
          ApplePressAndHoldEnabled = false;
        };
        "com.visualstudio.code.oss" = {
          ApplePressAndHoldEnabled = false;
        };
      };
      dock.persistent-apps = [
        { app = "/System/Cryptexes/App/System/Applications/Safari.app/"; }
        { app = "/Applications/Ghostty.app/"; }
        { app = "${pkgs-unstable.zed-editor}/Applications/Zed.app/"; }
        { app = "/Applications/Zotero.app/"; }
        { app = "/Applications/Things3.app/"; }
        { app = "/System/Applications/Calendar.app/"; }
        { app = "/Applications/ChatGPT.app/"; }
        { app = "/Applications/Linear.app/"; }
        { app = "/Applications/Discord.app/"; }
        { app = "/System/Applications/Mail.app/"; }
        { app = "/System/Applications/Music.app/"; }
      ];
    };
  };

  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
    brews = [
      "docker"
      "mas"
      "ghidra"
    ];
    masApps = {
      # Essentials
      "Things 3" = 904280696;
      "XCode" = 497799835;
      # Design
      "Sketch" = 1667260533;
      # Office
      "Microsoft Word" = 462054704;
      "Microsoft Excel" = 462058435;
      "OneDrive" = 823766827;
      "Numbers" = 361304891;
      "Keynote" = 361285480;
      "Pages" = 361309726;
      # Safari extensions
      "SponsorBlock for Safari" = 1573461917;
      "Userscripts" = 1463298887;
      "Wipr" = 1320666476;
      "Vimlike" = 1584519802;
      # Music
      "Logic Pro" = 634148309;
      "forScore" = 363738376;
      # Video
      "Final Cut Pro" = 424389933;
      "Infuse" = 1136220934;
      # 3D
      "Shapr3D" = 1091675654;
      # Utils
      "DaisyDisk" = 411643860;
      "Flighty" = 1358823008;
      "field-kit" = 1612653346;
      "Windows App" = 1295203466;
      "Tailscale" = 1475387142;
    };
    casks = [
      "karabiner-elements"
      "iina"
      "stolendata-mpv"
      "unnaturalscrollwheels"
      "figma"
      # these probably could get moved to the linux config
      # if I start using that as a desktop ever
      "syncplay"
      "discord"
      "slack"
      "zotero"
      "ghostty"
      "mullvad-vpn"
      "linear-linear"
      "obs"
      "obsidian"
      "notion"
      "visual-studio-code"
      "chatgpt"
      "logitech-g-hub"
      "plex"
      "steam"
      "battle-net"
      # browsers
      "firefox"
      "google-chrome"
      "microsoft-teams"
      "transmission"
    ];
  };

  services.aerospace = {
    enable = true;
    settings = {
      gaps = {
        inner.horizontal = 16;
        inner.vertical = 16;
        outer.left = 16;
        outer.bottom = [
          { monitor.main = 8; }
          16
        ];
        outer.top = 8;
        outer.right = 16;
      };
      on-focus-changed = [ "move-mouse window-lazy-center" ];
      mode.main.binding = {
        alt-slash = "layout tiles horizontal vertical";
        alt-comma = "layout accordion horizontal vertical";
        alt-h = "focus left";
        alt-j = "focus down";
        alt-k = "focus up";
        alt-l = "focus right";
        alt-shift-h = "move left";
        alt-shift-j = "move down";
        alt-shift-k = "move up";
        alt-shift-l = "move right";
        alt-minus = "resize smart -50";
        alt-equal = "resize smart +50";
        alt-w = "workspace W"; # Web
        alt-c = "workspace C"; # Code
        alt-r = "workspace R"; # Research
        alt-t = "workspace T"; # Tasks
        alt-m = "workspace M"; # Media
        alt-n = "workspace N"; # Notes
        alt-d = "workspace D"; # Dicord / Comms
        alt-g = "workspace G"; # Games
        alt-shift-w = "move-node-to-workspace W";
        alt-shift-c = "move-node-to-workspace C";
        alt-shift-r = "move-node-to-workspace R";
        alt-shift-t = "move-node-to-workspace T";
        alt-shift-m = "move-node-to-workspace M";
        alt-shift-n = "move-node-to-workspace N";
        alt-shift-d = "move-node-to-workspace D";
        alt-shift-g = "move-node-to-workspace G";
        alt-tab = "workspace-back-and-forth";
        alt-shift-tab = "move-workspace-to-monitor --wrap-around next";
        alt-shift-semicolon = "mode service";
      };
      mode.service.binding = {
        esc = [
          "reload-config"
          "mode main"
        ];
        r = [
          "flatten-workspace-tree"
          "mode main"
        ];
        f = [
          "layout floating tiling"
          "mode main"
        ];
        backspace = [
          "close-all-windows-but-current"
          "mode main"
        ];
        alt-shift-h = [
          "join-with left"
          "mode main"
        ];
        alt-shift-j = [
          "join-with down"
          "mode main"
        ];
        alt-shift-k = [
          "join-with up"
          "mode main"
        ];
        alt-shift-l = [
          "join-with right"
          "mode main"
        ];
      };
      workspace-to-monitor-force-assignment = {
        W = [
          "main"
          "secondary"
        ];
        C = "main";
        R = "main";
        D = "secondary";
        M = [
          "secondary"
          "main"
        ];
      };
      on-window-detected = [
        {
          "if" = {
            app-id = "com.mitchellh.ghostty";
          };
          run = [
            "layout floating"
            "move-node-to-workspace C"
          ];
        }
        {
          "if" = {
            app-id = "com.apple.Passwords";
          };
          run = [ "layout floating" ];
        }
        {
          "if" = {
            app-id = "com.hnc.Discord";
          };
          run = [ "move-node-to-workspace D" ];
        }
        {
          "if" = {
            app-id = "com.openai.chat";
          };
          run = [ "move-node-to-workspace D" ];
        }
        {
          "if" = {
            app-id = "com.apple.Music";
          };
          run = [ "move-node-to-workspace M" ];
        }
        {
          "if" = {
            app-id = "com.apple.Safari";
          };
          run = [ "move-node-to-workspace W" ];
        }
        {
          "if" = {
            app-id = "com.apple.mail";
          };
          run = [ "move-node-to-workspace D" ];
        }
        {
          "if" = {
            app-id = "com.microsoft.teams2";
          };
          run = [ "move-node-to-workspace D" ];
        }
        {
          "if" = {
            app-id = "com.apple.iCal";
          };
          run = [ "move-node-to-workspace T" ];
        }
        {
          "if" = {
            app-id = "com.linear";
          };
          run = [ "move-node-to-workspace T" ];
        }
        {
          "if" = {
            app-id = "com.culturedcode.ThingsMac";
          };
          run = [ "move-node-to-workspace T" ];
        }
        {
          "if" = {
            app-id = "com.zed.Zed";
          };
          run = [ "move-node-to-workspace C" ];
        }
        {
          "if" = {
            app-id = "com.openai.codex";
          };
          run = [ "move-node-to-workspace C" ];
        }
        {
          "if" = {
            app-id = "ai.opencode.desktop";
          };
          run = [ "move-node-to-workspace C" ];
        }
        {
          "if" = {
            app-id = "org.zotero.zotero";
          };
          run = [ "move-node-to-workspace R" ];
        }
        {
          "if" = {
            app-id = "notion.id";
          };
          run = [ "move-node-to-workspace N" ];
        }
        {
          "if" = {
            app-id = "md.obsidian";
          };
          run = [ "move-node-to-workspace N" ];
        }
        {
          "if" = {
            app-id = "com.valvesoftware.steam";
          };
          run = [ "move-node-to-workspace G" ];
        }
        {
          "if" = {
            app-id = "net.battle.app";
          };
          run = [ "move-node-to-workspace G" ];
        }
        {
          "if" = {
            app-id = "com.overwolf.curseforge";
          };
          run = [ "move-node-to-workspace G" ];
        }
      ];
    };
  };

  # The user should already exist, but we need to set this up so Nix knows
  # what our home directory is (https://github.com/LnL7/nix-darwin/issues/423).
  users.users.rain = {
    home = "/Users/rain";
    shell = pkgs.zsh;
  };
}
