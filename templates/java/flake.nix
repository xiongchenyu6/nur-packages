# SPDX-FileCopyrightText: 2021 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: CC0-1.0
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    devshell = {
      url = "github:numtide/devshell";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
    };

  };

  outputs = { self, nixpkgs, flake-utils, devshell, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ devshell.overlay ];
          config.allowUnfree = true;
        };
      in {
        packages.default = pkgs.callPackage ./default.nix { };
        devShell = pkgs.devshell.mkShell {
          env = [{
            name = "JAVA_HOME";
            value = "${pkgs.openjdk11}";
          }];
          commands = [
            {
              category = "Programming language support";
              package = pkgs.openjdk11;
              help = ''
                1. use gradle assemble to install dependency first
                              2. use gradle build -x test for dev build 
                              3. go to node/build/lib to find jars 
              '';
            }
            {
              category = "Java package manager";
              package = pkgs.gradle.override { java = pkgs.openjdk11; };
              name = "gradle";
              help = ''
                1. use gradle assemble to install dependency first
                              2. use gradle build -x test for dev build 
                              3. go to node/build/lib to find jars 
              '';
            }
            {
              category = "Java package manager";
              package = pkgs.nodejs-14_x;
              name = "nodejs";
            }
            { package = pkgs.python2; }
          ];
        };
      });
}
