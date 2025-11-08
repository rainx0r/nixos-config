{
  config,
  pkgs,
  pkgs-unstable,
  ...
}:

let
  sshPort = 4088;
  unstablePkgsForKernel = pkgs-unstable.linuxPackagesFor config.boot.kernelPackages.kernel;
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
  boot.loader.limine = {
    enable = true;
    secureBoot.enable = true;
    maxGenerations = 3;
    extraEntries = ''
      /Windows 11
        protocol: efi
        path: guid(765ca34f-751e-4206-88cb-3d4f339867d8):/EFI/Microsoft/Boot/bootmgfw.efi
      /memtest86
        protocol: efi
        path: boot():/limine/efi/memtest86/memtest86.efi
    '';
    additionalFiles = {
      "efi/memtest86/memtest86.efi" = "${pkgs.memtest86-efi}/BOOTX64.efi";
    };
    style = {
      wallpapers = [ ];
      interface = {
        resolution = "2560x1440";
        helpHidden = true;
        branding = "rainx0r's workstation";
        brandingColor = 6;
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
    package = unstablePkgsForKernel.nvidiaPackages.stable;
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
