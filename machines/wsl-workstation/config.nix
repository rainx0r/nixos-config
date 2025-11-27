{ pkgs, currentSystemUser, ... }:

{
  imports = [ ];

  wsl = {
    enable = true;
    wslConf.automount.root = "/mnt";
    defaultUser = currentSystemUser;
    startMenuLaunchers = true;
    useWindowsDriver = true;
  };

  ### Mount actual NixOS /home to WSL
  fileSystems."/home" = {
    device = "/mnt/wsl/PHYSICALDRIVE0p3/home";
    fsType = "none";
    options = [ "bind" ];
  };

  system.stateVersion = "25.05";
  nix.package = pkgs.nixVersions.latest;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  ### Locale
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };

  ### System-wide packages
  environment.systemPackages = with pkgs; [
    ghostty.terminfo
    nvtopPackages.nvidia
  ];

  ### Networking
  networking.hostName = "linux-workstation";
  networking.networkmanager.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 4088 ];
  };

  ## SSH Server
  services.openssh = {
    enable = true;
    ports = [ 4088 ];
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "rain" ];
    };
  };
  services.fail2ban.enable = true;
}
