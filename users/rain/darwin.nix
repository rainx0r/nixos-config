{ inputs, pkgs, ... }:

{
  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    onActivation.autoUpdate = true;
    onActivation.upgrade = true;
    brews = [
      "docker"
      "mas"
    ];
    masApps = {
      # Essentials
      "Things 3" = 904237743;
      "XCode" = 497799835;
      # Design
      "Affinity Publisher 2" = 1606941598;
      "Affinity Photo 2" = 1616822987;
      "Affinity Designer 2" = 1616831348;
      "Sketch" = 1667260533;
      # Office
      "Microsoft Word" = 462054704;
      "Microsoft Excel" = 462058435;
      "OneDrive" = 823766827;
      "Numbers" = 409203825;
      # Safari extensions
      "SponsorBlock for Safari" = 1573461917;
      "Userscripts" = 1463298887;
      "Wipr" = 1320666476;
      "Bitwarden" = 1352778147;
      # Music
      "forScore" = 363738376;
      "Logic Pro" = 634148309;
      # Utils
      "DaisyDisk" = 411643860;
      "AppCleaner" = 1616505989;
    };
    casks = [
      "karabiner-elements"
      "iina"
      "swiftformat-for-xcode"
      "unnaturalscrollwheels"
      "figma"
      "betterdisplay"
      # these probably could get moved to the linux config
      # if I start usnig that as a desktop ever
      "discord"
      "slack"
      "zotero"
      "ghostty"
      "mullvadvpn"
      "linear-linear"
      "ghidra"
      "obsidian"
      "obs"
      "notion"
      "zed"
    ];
  };

  # The user should already exist, but we need to set this up so Nix knows
  # what our home directory is (https://github.com/LnL7/nix-darwin/issues/423).
  users.users.rain = {
    home = "/Users/rain";
    shell = pkgs.zsh;
  };
}
