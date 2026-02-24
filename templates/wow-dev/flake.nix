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
              lua51
              luacheck
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
              cat >"$tmp/.luarc.json" <<'JSON'
              {
                "$schema": "https://raw.githubusercontent.com/sumneko/vscode-lua/master/setting/schema.json",
                "runtime.version": "Lua 5.1",
                "misc.parameters": ["--develop=true"],
                "workspace.library": [
                  "${wow-api}/Annotations"
                ],
                "diagnostics.disable": [
                  "unused-local",
                  "redefined-local",
                  "empty-block",
                  "invisible",
                  "deprecated",
                  "duplicate-doc-field"
                ]
              }
              JSON
              rm -f "$logdir/check.json"
              lua-language-server \
                --check="$target" \
                --checklevel=Information \
                --configpath="$tmp/.luarc.json" \
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
              lua51
              luacheck
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
