{ pkgs, ... }:

{
  system = {
    stateVersion = 5;
    primaryUser = "rain";

    defaults = {
      NSGlobalDomain = {
        KeyRepeat = 2; # 120, 90, 60, 30, 12, 6, 2
        InitialKeyRepeat = 15; # 120, 94, 68, 35, 25, 15
      };
      dock.persistent-apps = [
        { app = "/System/Cryptexes/App/System/Applications/Safari.app"; }
        { app = "/Applications/Ghostty.app/"; }
        { app = "/Applications/Zed.app/"; }
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
      "Numbers" = 409203825;
      "Keynote" = 409183694;
      "Pages" = 409183694;
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
      # Utils
      "DaisyDisk" = 411643860;
      "Flighty" = 1358823008;
      "field-kit" = 1612653346;
      "Windows App" = 1295203466;
    };
    casks = [
      "karabiner-elements"
      "iina"
      "stolendata-mpv"
      "swiftformat-for-xcode"
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
      "zed"
      "visual-studio-code"
      "chatgpt"
      "logitech-g-hub"
      "plex"
      "steam"
      # browsers
      "firefox"
      "google-chrome"
    ];
  };

  # The user should already exist, but we need to set this up so Nix knows
  # what our home directory is (https://github.com/LnL7/nix-darwin/issues/423).
  users.users.rain = {
    home = "/Users/rain";
    shell = pkgs.zsh;
  };
}
