{
  config,
  pkgs,
  lib,
  ...
}:

{
  programs.zsh.enable = true;
  programs.nix-ld = {
    enable = true;
  };

  environment.pathsToLink = [ "/share/zsh" ];
  environment.sessionVariables.LD_LIBRARY_PATH = lib.makeLibraryPath [
    pkgs.addDriverRunpath.driverLink
  ];
  environment.localBinInPath = true;

  users.users.rain = {
    isNormalUser = true;
    home = "/home/rain";
    extraGroups =
      [
        "wheel"
      ]
      ++ lib.optional config.virtualisation.docker.enable "docker"
      ++ lib.optional config.networking.networkmanager.enable "networkmanager";
    shell = pkgs.zsh;
  };
}
