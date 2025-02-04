{ pkgs, inputs, ... }:

{
  programs.zsh.enable = true;
  programs.nix-ld.enable = true;

  environment.pathsToLink = [ "/share/zsh" ];
  environment.localBinInPath = true;

  users.users.rain = {
    isNormalUser = true;
    home = "/home/rain";
    extraGroups = [ "wheel" "docker" "networkmanager" ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICE98f6We/XXN5BMxPTYRyYTb9HHvAysWZ0ZBXCoOjJD evangelos-ch@Angels-MacBook-Pro.local"
    ];
  };
}
