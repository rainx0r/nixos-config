{
  description = "PyTorch dev shell: C toolchain for torch.compile and triton, Python left to uv.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-26.05";
  };

  outputs =
    { nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        rec {
          pytorch = pkgs.mkShell {
            packages = [ pkgs.openssl ];
            env = {
              NIX_ENFORCE_NO_NATIVE = "0";
            };
          };
          default = pytorch;
        }
      );
    };
}
