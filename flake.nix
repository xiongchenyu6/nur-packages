{
  description = "My personal NUR repository";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    flake-parts.url = "github:hercules-ci/flake-parts";
    dream2nix = {
      url = "github:nix-community/dream2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pkgs-by-name-for-flake-parts.url = "github:drupol/pkgs-by-name-for-flake-parts";

    # sub2api is packaged upstream here; we only re-export it.
    llm-agents = {
      url = "github:numtide/llm-agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      dream2nix,
      pkgs-by-name-for-flake-parts,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { inputs, ... }:
      {

        # Note: Not importing pkgs-by-name-for-flake-parts to avoid automatic discovery of incompatible packages
        # imports = [
        #   inputs.pkgs-by-name-for-flake-parts.flakeModule
        # ];
        systems = [
          "x86_64-linux"
          "aarch64-linux"
          "aarch64-darwin"
          "x86_64-darwin"
        ];

        perSystem =
          {
            lib,
            system,
            ...
          }:
          let
            # Own nixpkgs instance so unfree packages (unity-cli, feishu-lark,
            # falcon-sensor, ...) evaluate with plain `nix build .#<name>`.
            # garnix CI is include-list based, so this does not add CI builds.
            pkgs = import nixpkgs {
              inherit system;
              config.allowUnfree = true;
            };
            # Packages taken verbatim from other flakes instead of being
            # maintained here. Absent on systems the upstream does not build.
            upstreamPackages = lib.filterAttrs (n: _: n == "sub2api") (
              inputs.llm-agents.packages.${system} or { }
            );

          in
          {
            # pkgsDirectory = ./pkgs;
            # pkgsNameSeparator = "-";
            packages =
              let
                # default.nix already discovers everything under pkgs/ through
                # pkgs/manifest.nix and drops what meta.platforms excludes, so
                # there is no second list to maintain here. (This used to
                # re-walk pkgs/ behind builtins.tryEval, which silently hid
                # packages that failed to evaluate.)
                allPackages = import ./. {
                  inherit self lib pkgs;
                };

                combinedPackages = allPackages // upstreamPackages;
              in
              combinedPackages
              // {
                default = combinedPackages.librime or combinedPackages.default or null;
              };

            apps = {
              update = {
                type = "app";
                program = lib.getExe (
                  pkgs.writeShellApplication {
                    name = "update";
                    runtimeInputs = with pkgs; [
                      bash
                      coreutils
                      git
                      gnused
                      jq
                      nix
                      nvfetcher
                      perl
                      ripgrep
                    ];
                    text = ''
                      repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
                      cd "$repo_root"
                      bash ./scripts/update.sh
                    '';
                  }
                );
              };
            };
            devShells.default = pkgs.mkShell {
              buildInputs = with pkgs; [
                nixfmt-rfc-style
                nixd
                statix
              ];
            };
          };

        flake =
          let
            inherit (nixpkgs) lib;
            sub2apiFor = system: inputs.llm-agents.packages.${system}.sub2api;

            # The sub2api service modules take their package from llm-agents.nix
            # rather than from a local pkgs/ entry, so the default is wired in
            # here where the flake inputs are in scope.
            sub2apiPackageModule =
              { pkgs, ... }:
              {
                services.sub2api.package = lib.mkDefault (sub2apiFor pkgs.stdenv.hostPlatform.system);
              };
          in
          {
            # Overlay that provides all NUR packages
            # Uses lazy evaluation and super (prev) to avoid infinite recursion
            overlays.default = lib.composeExtensions (import ./overlay.nix) (
              _final: prev: {
                sub2api = sub2apiFor prev.stdenv.hostPlatform.system;
              }
            );

            nixosModules = import ./modules // {
              sub2api.imports = [
                ./modules/sub2api
                sub2apiPackageModule
              ];
            };
            homeModules = import ./modules/home.nix // {
              sub2api.imports = [
                ./modules/sub2api/home.nix
                sub2apiPackageModule
              ];
            };
            templates = import ./templates;
          };
      }
    );
}
