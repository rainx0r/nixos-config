{ pkgs, ... }:

{
  system.stateVersion = 5;

  nix.enable = false;

  programs.zsh.enable = true;
  environment.shells = with pkgs; [
    bashInteractive
    zsh
  ];

  networking.hostName = "mac-mini";
  services.openssh = {
    enable = true;
    # TODO: rewrite this for nix darwin
    #
    # settings = {
    #   PasswordAuthentication = false;
    #   KbdInteractiveAuthentication = false;
    #   PermitRootLogin = "no";
    #   X11Forwarding = false;
    #
    #   AllowUsers = [ "rain" ];
    #   Macs = [
    #     "hmac-sha2-512-etm@openssh.com"
    #     "hmac-sha2-256-etm@openssh.com"
    #     "umac-128-etm@openssh.com"
    #     "hmac-sha2-256"
    #     "hmac-sha2-512"
    #   ];
    # };
  };

  power.restartAfterPowerFailure = true;
  power.restartAfterFreeze = true;

  system.defaults.loginwindow = {
    autoLoginUser = null;
    SleepDisabled = true;
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
  '';

  system.defaults.SoftwareUpdate = {
    AutomaticallyInstallMacOSUpdates = false;
  };
}
