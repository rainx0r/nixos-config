{ config, pkgs, ... }:

let
  sshPort = 4088; # random port
in {
  imports = [
    ./hardware.nix
  ];

  ### OS
  system.stateVersion = "24.11";
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.cudaSupport = true;

  ### Bootloader
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # TODO: switch to lanzaboote for Secure Boot when usable
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 3;
    windows = {
      "11" = {
        title = "Windows 11";
        efiDeviceHandle = "HD2b";
        sortKey = "w_windows";
      };
    };
  };
  boot.loader.efi.canTouchEfiVariables = true;

  ### Audio
  services.pipewire = {
    enable = true;
    pulse.enable = true;
  };

  ### Video
  hardware.graphics = {
    enable = true;
  };
  hardware.nvidia = {
    # HACK: https://github.com/NixOS/nixpkgs/issues/375730#issuecomment-2625157971 for 6.13 kernel
    # TODO: remove this and switch to stable once the card is a bit older
    package = config.boot.kernelPackages.nvidiaPackages.mkDriver {
      version = "570.86.16"; # use new 570 drivers
      sha256_64bit = "sha256-RWPqS7ZUJH9JEAWlfHLGdqrNlavhaR1xMyzs8lJhy9U=";
      openSha256 = "sha256-DuVNA63+pJ8IB7Tw2gM4HbwlOh1bcDg2AN2mbEU9VPE=";
      settingsSha256 = "sha256-9rtqh64TyhDF5fFAYiWl3oDHzKJqyOW3abpcf2iNRT8=";
      usePersistenced = false;
    };
    modesetting.enable = true;
    powerManagement.enable = true;
    open = true;
    nvidiaSettings = true;
  };
  services.xserver.videoDrivers = [ "nvidia" ];

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
  ];

  ### Docker
  virtualisation.docker.enable = true;
  virtualisation.docker.storageDriver = "btrfs";

  ### Networking
  networking.hostName = "linux-workstation";
  networking.networkmanager.enable = true;
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ sshPort ];
  };

  ## SSH Server
  services.openssh = {
    enable = true;
    ports = [ sshPort ]; # random port
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "rain" ];
    };
  };
  services.fail2ban.enable = true;
}
