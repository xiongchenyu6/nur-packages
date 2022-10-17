{
  description = "My personal NUR repository";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    dream2nix.url = "github:nix-community/dream2nix";
    oci-arm-host-capacity-src = {
      url = "github:hitrov/oci-arm-host-capacity";
      flake = false;
    };

  };
  outputs = { self, nixpkgs, flake-utils, dream2nix, oci-arm-host-capacity-src
    , ... }@inputs:
    let
      lib = nixpkgs.lib;
      eachSystem = flake-utils.lib.eachSystemMap flake-utils.lib.allSystems;
    in {
      inherit eachSystem lib;

      packages = eachSystem (system:
        import ./. {
          inherit lib;
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          ci = false;
          inherit inputs;
          inherit dream2nix;
        });

      ciPackages = eachSystem (system:
        import ./. {
          inherit lib;
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
          ci = true;
          inherit inputs;
          inherit dream2nix;
        });

      # Following line doesn't work for infinite recursion
      # overlay = self: super: packages."${super.system}";
      overlay = import ./overlay.nix { inherit lib; };

      apps = eachSystem (system:
        let pkgs = import nixpkgs { inherit system; };
        in {
          ci = {
            type = "app";
            program = builtins.toString (pkgs.writeShellScript "ci" ''
              if [ "$1" == "" ]; then
                echo "Usage: ci <system>";
                exit 1;
              fi
              exec ${pkgs.nix-build-uncached}/bin/nix-build-uncached ci.nix -A $1 --show-trace
            '');
          };

          update = {
            type = "app";
            program = builtins.toString (pkgs.writeShellScript "update" ''
              nix flake update
              ${pkgs.nvfetcher}/bin/nvfetcher -c nvfetcher.toml -o _sources
            '');
          };
        });

      nixosModules = import ./modules;

      templates = import ./templates;

      hydraJobs = eachSystem (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };

        in {
          tester = self.packages.${system}.default.overrideAttrs (prev: {
            doCheck = true;
            keepBuildDirectory = true;
            #succeedOnFailure = true;
            TESTSUITEFLAGS =
              "NIX_DONT_SET_RPATH_x86_64_unknown_linux_gnu=1 -x -d";
            checkPhase = ''
              echo hello
            '';
            postInstall = ''
              echo hello
              echo world
            '';
            failureHook = ''
              test -f tests/testsuite.log && cp tests/testsuite.log $out/
              test -d tests/testsuite.dir && cp -r tests/testsuite.dir $out/
            '';
          });
          tester-readme = pkgs.runCommand "readme" { } ''
            echo hello worl
            mkdir -p $out/nix-support
            echo "# A readme" > $out/readme.md
            echo "doc readme $out/readme.md" >> $out/nix-support/hydra-build-products
          '';
        });

    };
}
