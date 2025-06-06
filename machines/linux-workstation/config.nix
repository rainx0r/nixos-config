{ config, pkgs, ... }:

let
  sshPort = 4088; # random port
in
{
  imports = [
    ./hardware.nix
  ];

  ### OS
  system.stateVersion = "24.11";
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nixpkgs.config.cudaSupport = true;
  nix.optimise.automatic = true;
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 30d";
  };

  ### Bootloader
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # TODO: switch to lanzaboote for Secure Boot when usable
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 3;
    windows = {
      "11" = {
        title = "Windows 11";
        efiDeviceHandle = "HD1b";
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
      version = "570.144";
      sha256_64bit = "sha256-wLjX7PLiC4N2dnS6uP7k0TI9xVWAJ02Ok0Y16JVfO+Y=";
      sha256_aarch64 = "sha256-6kk2NLeKvG88QH7/YIrDXW4sgl324ddlAyTybvb0BP0=";
      openSha256 = "sha256-PATw6u6JjybD2OodqbKrvKdkkCFQPMNPjrVYnAZhK/E=";
      settingsSha256 = "sha256-VcCa3P/v3tDRzDgaY+hLrQSwswvNhsm93anmOhUymvM=";
      persistencedSha256 = "sha256-hx4w4NkJ0kN7dkKDiSOsdJxj9+NZwRsZEuhqJ5Rq3nM=";
    };
    modesetting.enable = true;
    powerManagement.enable = true;
    open = true;
    nvidiaSettings = true;
  };
  hardware.nvidia-container-toolkit.enable = true;
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
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
    storageDriver = "btrfs";
    daemon.settings = {
      userland-proxy = false;
    };
  };
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      colab = {
        autoStart = true;
        image = "us-docker.pkg.dev/colab-images/public/runtime";
        ports = [ "9000:8080" ];
        extraOptions = [ "--device=nvidia.com/gpu=all" ];
      };
    };
  };

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
