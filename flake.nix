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

  };
  outputs = { self, nixpkgs, flake-parts, dream2nix, pkgs-by-name-for-flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } ({ inputs, ... }: 
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
        { pkgs, lib, system, ... }:
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
                  linuxOnlyPackages = [ "falcon-sensor" "feishu-lark" "haystack-editor" "record_screen" "sui" ];

                  # Function to safely import a package if it's compatible with the current system
                  tryImportPackage = name: path:
                    let
                      packageFile = path + "/package.nix";
                      isLinuxOnly = builtins.elem name linuxOnlyPackages;
                      isLinuxSystem = lib.hasSuffix "linux" system;
                    in
                    if builtins.pathExists packageFile &&
                       (!isLinuxOnly || isLinuxSystem) then
                      (let
                        result = builtins.tryEval (pkgs.callPackage packageFile {});
                      in
                      if result.success then
                        { ${name} = result.value; }
                      else
                        {})
                    else
                      {};
                  
                  # Get all package directories
                  pkgDirs = builtins.readDir ./pkgs;
                  
                  # Filter only directories
                  packageNames = builtins.filter (name: 
                    pkgDirs.${name} == "directory"
                  ) (builtins.attrNames pkgDirs);
                  
                  # Try to import each package
                  packageSets = map (name: 
                    tryImportPackage name (./pkgs + "/${name}")
                  ) packageNames;
                in
                builtins.foldl' (acc: set: acc // set) {} packageSets;
              # Combine all packages and set default
              combinedPackages = allPackages // pkgsByName;
            in
            combinedPackages // {
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
    });
}
