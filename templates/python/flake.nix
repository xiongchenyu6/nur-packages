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
        {
          devShells.default = pkgs.mkShell {
            buildInputs = with pkgs; [
              (python3.withPackages (python-pkgs: [
                python-pkgs.virtualenvwrapper
                python-pkgs.pip
              ]))
            ];
            shellHook =
              let
                lib-path = lib.makeLibraryPath (
                  with pkgs;
                  lib.optionals stdenv.isLinux [
                    nixfmt-rfc-style
                    nixd
                    stdenv.cc.cc
                  ]
                );
              in
              ''
                # Allow the use of wheels.
                SOURCE_DATE_EPOCH=$(date +%s)
                # Augment the dynamic linker path
                export "LD_LIBRARY_PATH=$LD_LIBRARY_PATH:${lib-path}"
                # Setup the virtual environment if it doesn't already exist.
                VENV=.venv
                if test ! -d $VENV; then
                  virtualenv $VENV
                fi
                source ./$VENV/bin/activate
                export PYTHONPATH=$PYTHONPATH:`pwd`/$VENV/${pkgs.python3.sitePackages}/
              '';
          };
        };
    };
}
