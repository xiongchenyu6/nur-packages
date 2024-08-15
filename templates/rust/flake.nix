# SPDX-FileCopyrightText: 2021 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: CC0-1.0
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = { nixpkgs, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, lib, ... }: {
        devShells.default =
          with pkgs; mkShell.override {stdenv = pkgs.clangStdenv; }{
            RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";
            RUST_BACKTRACE = 1;

            buildInputs = [
            nixfmt-rfc-style
            nil
            rustc
            cargo
            rust-analyzer
            clippy
            openssl
            rustfmt
          ];
            nativeBuildInputs = [ pkg-config ];
         };
      };
    };
}
