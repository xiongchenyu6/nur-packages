# SPDX-FileCopyrightText: 2021 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: CC0-1.0
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs =
    { nixpkgs, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      perSystem =
        {
          config,
          self',
          inputs',
          pkgs,
          system,
          lib,
          ...
        }:
        with pkgs;
        {
          packages.default = stdenv.mkDerivation {
            name = "corepack-shims";
            buildInputs = [ nodejs ];
            dontUnpack = true;
            installPhase = ''
              runHook preInstall
              mkdir -p $out/bin
              corepack enable --install-directory=$out/bin
              runHook postInstall
            '';
          };
          devShells.default =
            let
              # Only actual shared libraries belong here — listing tools like
              # nixfmt would add a nonexistent /lib and leave them off PATH.
              lib-path = lib.makeLibraryPath (
                with pkgs;
                lib.optionals stdenv.hostPlatform.isLinux [
                  stdenv.cc.cc
                ]
              );
            in
            pkgs.mkShell {
              buildInputs = with pkgs; [
                nixfmt
                nixd
                nodejs
                self'.packages.default
              ];
              # Set from the hook, not as a derivation attribute: attribute
              # values are passed through literally, so "$LD_LIBRARY_PATH"
              # would end up in the variable unexpanded.
              shellHook = ''
                export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH:+$LD_LIBRARY_PATH:}${lib-path}"
              '';
            };
        };
    };
}
