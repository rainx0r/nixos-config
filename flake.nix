{
  description = "NixOS systems and tools by rain";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-master.url = "github:nixos/nixpkgs";

    home-manager = {
      url = "github:nix-community/home-manager/release-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:LnL7/nix-darwin/nix-darwin-25.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nvim-config-rain = {
      url = "github:rainx0r/nvim";
      flake = false;
    };
  };

  outputs =
    inputs:
    let
      overlays = [
        (final: prev: {
          claude-code = inputs.nixpkgs-master.legacyPackages.${prev.stdenv.hostPlatform.system}.claude-code;
          codex = inputs.nixpkgs-master.legacyPackages.${prev.stdenv.hostPlatform.system}.codex;
          ty = inputs.nixpkgs-master.legacyPackages.${prev.stdenv.hostPlatform.system}.ty;
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
      };
      nixosConfigurations.wsl-workstation = mkSystem "wsl-workstation" {
        system = "x86_64-linux";
        user = "rain";
        wsl = true;
      };
      darwinConfigurations.macbook = mkSystem "macbook" {
        system = "aarch64-darwin";
        user = "rain";
        darwin = true;
      };
    };
}
