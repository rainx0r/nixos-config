{ pkgs, pkgs-unstable, ... }:

{
  system.stateVersion = 5;

  nix.enable = false;

  programs.zsh.enable = true;
  environment.shells = with pkgs; [
    bashInteractive
    zsh
  ];
  environment.systemPackages = with pkgs; [
    mosh
  ];
  homebrew.casks = [
    "plex-media-server"
  ];

  services.tailscale = {
    enable = true;
    package = pkgs-unstable.tailscale;
  };

  networking.hostName = "mac-mini";
  services.openssh = {
    enable = true;
    extraConfig = ''
      PasswordAuthentication no
      KbdInteractiveAuthentication no
      PermitRootLogin no
      X11Forwarding no

      AllowUsers rain
      MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-256,hmac-sha2-512
    '';
  };

  power.restartAfterPowerFailure = true;
  power.restartAfterFreeze = true;

  system.defaults.loginwindow = {
    autoLoginUser = "rain";
    SleepDisabled = true;
  };
  system.defaults.screensaver = {
    askForPassword = true;
    askForPasswordDelay = 0;
  };
  launchd.user.agents.lockAfterAutologin = {
    script = ''
      /bin/sleep 30
      "/System/Library/CoreServices/Menu Extras/User.menu/Contents/Resources/CGSession" -suspend
    '';
    serviceConfig.RunAtLoad = true;
  };
  system.activationScripts.serverPower.text = ''
    # Never sleep automatically
    /usr/bin/pmset -a sleep 0

    # Let display sleep separately; minutes
    /usr/bin/pmset -a displaysleep 90

    # Wake on network access
    /usr/bin/pmset -a womp 1

    # Restart after power failure
    /usr/bin/pmset -a autorestart 1

    # Don't spin disks down aggressively
    /usr/bin/pmset -a disksleep 0
  '';

  system.defaults.SoftwareUpdate = {
    AutomaticallyInstallMacOSUpdates = false;
  };

  users.users.rain.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHRHH7u+Q8iK3E/jYz97Nmb8w8rI4g8O0D9KX6EW4ACC rain@macbook"
  ];
}
