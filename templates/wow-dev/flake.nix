{
  description = "WoW Addon dev shell. Great inspiration taken from DBM repos.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    wow-api = {
      url = "git+https://github.com/Ketho/vscode-wow-api.git?submodules=1";
      flake = false;
    };
  };

  outputs =
    {
      nixpkgs,
      wow-api,
      ...
    }:
    let
      systems = [
        "aarch64-darwin"
        "x86_64-darwin"
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = f: nixpkgs.lib.genAttrs systems (system: f system);
    in
    {
      devShells = forAllSystems (
        system:
        let
          pkgs = import nixpkgs { inherit system; };

          wow-lint = pkgs.writeShellApplication {
            name = "wow-lint";
            runtimeInputs = with pkgs; [
              jq
              lua5_1
              lua51Packages.luacheck
              lua-language-server
              stylua
            ];
            text = ''
              set -euo pipefail
              target="''${1:-.}"

              luacheck "$target"

              # 2) LuaLS check (diagnostics report)
              tmp="$(mktemp -d)"
              trap 'rm -rf "$tmp"' EXIT
              logdir="$tmp/log"
              mkdir -p "$logdir"
              rm -f "$logdir/check.json"
              lua-language-server \
                --check="$target" \
                --checklevel=Information \
                --configpath=".wow-dev-internal/Check.lua" \
                --api_libraries="${wow-api}/Annotations"
                --logpath="$logdir"
              if [[ -s "$logdir/check.json" ]]; then
                echo
                echo "LuaLS diagnostics:"
                jq -r '
                  to_entries
                  | map(.key as $file | .value[]
                      | "\(
                          if .severity <= 1 then "ERROR"
                          else "WARN"
                          end
                        ): \($file) \(.range.start.line + 1):\(.range.start.character + 1) \(.code) - \(.message)"
                    )
                  | .[]
                ' "$logdir/check.json"
                exit 1
              fi

              stylua --check "$target"
            '';
          };

        in
        rec {
          wow = pkgs.mkShell {
            packages = with pkgs; [
              lua5_1
              lua51Packages.luacheck
              lua-language-server
              stylua
              wow-lint
            ];

            shellHook = ''
              echo "🧙 WoW dev shell: Lua 5.1 + luacheck + LuaLS + stylua"
              echo "Run: wow-lint [path]"
            '';
          };
          default = wow;
        }
      );
    };
}
