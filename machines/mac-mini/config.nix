{ pkgs, ... }:

{
  system.stateVersion = 5;

  nix.enable = false;

  networking.hostName = "mac-mini";

  programs.zsh.enable = true;
  environment.shells = with pkgs; [
    bashInteractive
    zsh
  ];
}
