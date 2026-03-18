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

    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dify-src = {
      url = "github:langgenius/dify/1.13.1";
      flake = false;
    };

  };
  outputs =
    {
      self,
      nixpkgs,
      flake-parts,
      dream2nix,
      pkgs-by-name-for-flake-parts,
      uv2nix,
      pyproject-nix,
      pyproject-build-systems,
      dify-src,
      ...
    }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } (
      { inputs, ... }:
      let
        # Load the Dify workspace (system-independent, only parses pyproject.toml + uv.lock)
        difyWorkspace = uv2nix.lib.workspace.loadWorkspace {
          workspaceRoot = "${dify-src}/api";
        };
      in
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
            pkgs,
            lib,
            system,
            ...
          }:
          let
            isLinuxSystem = lib.hasSuffix "linux" system;

            # Overrides for sdist packages missing build system declarations
            difyPyprojectOverrides =
              final: prev:
              let
                # Helper to add setuptools as build dependency
                addSetuptools =
                  name:
                  prev.${name}.overrideAttrs (old: {
                    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
                      (final.resolveBuildSystem { setuptools = [ ]; })
                    ];
                  });
                # Packages that need setuptools but don't declare it
                setuptools-packages = [
                  "alibabacloud-credentials-api"
                  "alibabacloud-endpoint-util"
                  "alibabacloud-gateway-spi"
                  "alibabacloud-credentials"
                  "alibabacloud-gpdb20160503"
                  "esdk-obs-python"
                  "psycogreen"
                  "jieba"
                ];
              in
              lib.genAttrs setuptools-packages (name: addSetuptools name);

            # Build the Dify Python environment (only on Linux)
            difyPythonSet = lib.optionalAttrs isLinuxSystem (
              (pkgs.callPackage pyproject-nix.build.packages {
                python = pkgs.python312;
              }).overrideScope
                (
                  lib.composeManyExtensions [
                    pyproject-build-systems.overlays.default
                    (difyWorkspace.mkPyprojectOverlay { sourcePreference = "wheel"; })
                    difyPyprojectOverrides
                  ]
                )
            );

            difyApiEnv = lib.optionalAttrs isLinuxSystem (
              difyPythonSet.mkVirtualEnv "dify-api-env" difyWorkspace.deps.default
            );

            difyPackages = lib.optionalAttrs isLinuxSystem {
              dify-api = pkgs.callPackage ./pkgs/dify/api/package.nix {
                inherit difyApiEnv;
                inherit dify-src;
              };
              dify-web = pkgs.callPackage ./pkgs/dify/web/package.nix { };
            };
          in
          {
            # pkgsDirectory = ./pkgs;
            # pkgsNameSeparator = "-";
            packages =
              let
                # Import packages from default.nix
                allPackages = import ./. {
                  inherit self lib pkgs;
                };

                # Manually import packages from pkgs/ directory with platform filtering
                pkgsByName =
                  let
                    # Platform-specific package mapping
                    linuxOnlyPackages = [
                      "falcon-sensor"
                      "feishu-lark"
                      "haystack-editor"
                      "record_screen"
                      "roxybrowser"
                      "sui"
                    ];

                    # Function to safely import a package if it's compatible with the current system
                    tryImportPackage =
                      name: path:
                      let
                        packageFile = path + "/package.nix";
                        isLinuxOnly = builtins.elem name linuxOnlyPackages;
                        isLinuxSystem' = lib.hasSuffix "linux" system;
                      in
                      if builtins.pathExists packageFile && (!isLinuxOnly || isLinuxSystem') then
                        (
                          let
                            result = builtins.tryEval (pkgs.callPackage packageFile { });
                          in
                          if result.success then { ${name} = result.value; } else { }
                        )
                      else
                        { };

                    # Get all package directories
                    pkgDirs = builtins.readDir ./pkgs;

                    # Filter only directories
                    packageNames = builtins.filter (name: pkgDirs.${name} == "directory") (builtins.attrNames pkgDirs);

                    # Try to import each package
                    packageSets = map (name: tryImportPackage name (./pkgs + "/${name}")) packageNames;
                  in
                  builtins.foldl' (acc: set: acc // set) { } packageSets;
                # Combine all packages and set default
                combinedPackages = allPackages // pkgsByName // difyPackages;
              in
              combinedPackages
              // {
                default = combinedPackages.librime or combinedPackages.default or null;
              };

            apps = {
              update = {
                type = "app";
                program = builtins.toString (
                  pkgs.writeShellScript "update" ''
                    nix flake update
                    # ${pkgs.nvfetcher}/bin/nvfetcher -c nvfetcher.toml -o _sources
                  ''
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

        flake = {
          # Overlay that provides all NUR packages
          # Uses lazy evaluation and super (prev) to avoid infinite recursion
          overlays.default = import ./overlay.nix;

          nixosModules = import ./modules;
          templates = import ./templates;
        };
      }
    );
}
