{
  nixpkgs,
  nixpkgs-unstable,
  inputs,
}:

name:
{
  system,
  user,
  darwin ? false,
}:

let
  machineConfig = ../machines/${name}/config.nix;
  userOSConfig = ../users/${user}/${if darwin then "darwin" else "nixos"}.nix;
  userHMConfig = ../users/${user}/home-manager.nix;

  systemFunc = if darwin then inputs.darwin.lib.darwinSystem else nixpkgs.lib.nixosSystem;
  home-manager =
    if darwin then inputs.home-manager.darwinModules else inputs.home-manager.nixosModules;
in
systemFunc rec {
  inherit system;

  modules = [
    { nixpkgs.config.allowUnfree = true; }
    {
      # HACK: Fix nodejs on darwin https://github.com/NixOS/nixpkgs/issues/402079
      nixpkgs.overlays = [
        (self: super: {
          nodejs = super.nodejs_22;
        })
      ];
    }

    machineConfig
    userOSConfig
    home-manager.home-manager
    {
      home-manager.useGlobalPkgs = true;
      home-manager.useUserPackages = true;
      home-manager.extraSpecialArgs = {
        unstable = import nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };
      };

      home-manager.users.${user} = import userHMConfig {
        inputs = inputs;
      };
    }

    {
      config._module.args = {
        currentSystem = system;
        currentSystemName = name;
        currentSystemUser = user;
        inputs = inputs;
      };
    }
  ];
}
