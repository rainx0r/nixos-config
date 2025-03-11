{
  description = "NixOS systems and tools by rain";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvim-config-rain = {
      url = "git+file:users/rain/nvim";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      darwin,
      nvim-config-rain,
      ...
    }@inputs:
    let
      mkSystem = import ./lib/mksystem.nix {
        inherit nixpkgs nixpkgs-unstable inputs;
      };
    in
    {
      nixosConfigurations.linux-workstation = mkSystem "linux-workstation" {
        system = "x86_64-linux";
        user = "rain";
      };
      darwinConfigurations.macbook = mkSystem "macbook" {
        system = "aarch64-darwin";
        user = "rain";
        darwin = true;
      };
    };
}
