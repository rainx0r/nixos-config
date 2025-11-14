{ pkgs, ... }:

{
  system.stateVersion = 5;

  nix = {
    extraOptions = ''
      experimental-features = nix-command flakes
      keep-outputs = true
      keep-derivations = true
    '';
  };

  nix.gc = {
    automatic = true;
    interval = {
      Weekday = 0;
      Hour = 0;
      Minute = 0;
    };
    options = "--delete-older-than 30d";
  };

  programs.zsh.enable = true;
  environment.shells = with pkgs; [
    bashInteractive
    zsh
  ];
}
