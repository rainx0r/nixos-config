{ pkgs, lib, ... }:

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
    extraGroups = [
      "wheel"
      "docker"
      "networkmanager"
    ];
    shell = pkgs.zsh;
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHRHH7u+Q8iK3E/jYz97Nmb8w8rI4g8O0D9KX6EW4ACC rain@macbook"
    ];
  };
}
