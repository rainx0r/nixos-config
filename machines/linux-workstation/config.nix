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
  hardware.nvidia =
    let
      gpl_symbols_linux_615_patch = pkgs.fetchpatch {
        url = "https://github.com/CachyOS/kernel-patches/raw/914aea4298e3744beddad09f3d2773d71839b182/6.15/misc/nvidia/0003-Workaround-nv_vm_flags_-calling-GPL-only-code.patch";
        hash = "sha256-YOTAvONchPPSVDP9eJ9236pAPtxYK5nAePNtm2dlvb4=";
        stripLen = 1;
        extraPrefix = "kernel/";
      };

      nvidiaPackage = config.boot.kernelPackages.nvidiaPackages.mkDriver {
        version = "575.57.08";
        sha256_64bit = "sha256-KqcB2sGAp7IKbleMzNkB3tjUTlfWBYDwj50o3R//xvI=";
        sha256_aarch64 = "sha256-VJ5z5PdAL2YnXuZltuOirl179XKWt0O4JNcT8gUgO98=";
        openSha256 = "sha256-DOJw73sjhQoy+5R0GHGnUddE6xaXb/z/Ihq3BKBf+lg=";
        settingsSha256 = "sha256-AIeeDXFEo9VEKCgXnY3QvrW5iWZeIVg4LBCeRtMs5Io=";
        persistencedSha256 = "sha256-Len7Va4HYp5r3wMpAhL4VsPu5S0JOshPFywbO7vYnGo=";
        patches = [ gpl_symbols_linux_615_patch ];
      };

    in
    {
      # HACK: https://github.com/NixOS/nixpkgs/issues/375730#issuecomment-2625157971 for 6.13 kernel
      # TODO: remove this and switch to stable once the card is a bit older
      package = nvidiaPackage;
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
    nvtopPackages.nvidia
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
