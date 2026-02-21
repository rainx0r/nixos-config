{
  inputs,
  overlays,
}:

name:
{
  system,
  user,
  darwin ? false,
  wsl ? false,
  nixpkgsForSystem ? inputs.nixpkgs,
}:

let
  machineConfig = ../machines/${name}/config.nix;
  userOSConfig = ../users/${user}/${if darwin then "darwin" else "nixos"}.nix;
  userHMConfig = ../users/${user}/home-manager.nix;
  nixpkgsConfig = {
    allowUnfree = true;
  };
  systemFunc = if darwin then inputs.darwin.lib.darwinSystem else nixpkgsForSystem.lib.nixosSystem;
  home-manager =
    if darwin then inputs.home-manager.darwinModules else inputs.home-manager.nixosModules;
  pkgs-unstable = import inputs.nixpkgs-unstable {
    inherit system overlays;
    config = nixpkgsConfig;
  };
  isWSL = wsl;
in
systemFunc rec {
  inherit system;

  specialArgs = {
    inherit inputs pkgs-unstable;
    currentSystem = system;
    currentSystemName = name;
    currentSystemUser = user;
  };

  modules = [
    {
      nixpkgs.config = nixpkgsConfig;
      nixpkgs.overlays = overlays;
    }

    # Bring in WSL if this is a WSL build
    (if isWSL then inputs.nixos-wsl.nixosModules.wsl else { })

    machineConfig
    userOSConfig
    home-manager.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = specialArgs;
      home-manager.backupFileExtension = "hm-backup";
      home-manager.users.${user} = import userHMConfig;
    }
  ];
}
