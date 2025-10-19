{
  description = "NixOS systems and tools by rain";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvim-config-rain = {
      url = "git+file:users/rain/nvim";
      flake = false;
    };
  };

  outputs =
    inputs:
    let
      overlays = [
        (final: prev: {
          # HACK: Fix nodejs on darwin https://github.com/NixOS/nixpkgs/issues/402079
          nodejs = prev.nodejs_22;

          codex = inputs.nixpkgs-master.legacyPackages.${prev.system}.codex;
        })
      ];

      mkSystem = import ./lib/mksystem.nix {
        inherit overlays inputs;
      };
    in
    {
      nixosConfigurations.linux-workstation = mkSystem "linux-workstation" {
        system = "x86_64-linux";
        user = "rain";
        # TODO: change back to stable when limine secureBoot is in
        nixpkgsForSystem = inputs.nixpkgs-unstable;
      };
      darwinConfigurations.macbook = mkSystem "macbook" {
        system = "aarch64-darwin";
        user = "rain";
        darwin = true;
      };
    };
}
