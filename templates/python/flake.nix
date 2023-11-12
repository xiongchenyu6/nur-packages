# SPDX-FileCopyrightText: 2021 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: CC0-1.0

{
  inputs = {

    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, flake-utils, devenv, ... }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = import nixpkgs { inherit system; };
      in {
        devShell = devenv.lib.mkShell {
          inherit inputs pkgs;

          modules = [
            ({ pkgs, ... }: {
              # This is your devenv configuration
              packages = with pkgs; [ poetry ];
              languages = {
                python = {
                  enable = true;
                  poetry = {
                    enable = true;
                    activate.enable = true;
                    install.enable = true;
                    install.allExtras = true;
                  };
                };
              };
            })
          ];
        };
      });
}
