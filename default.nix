# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage
{ pkgs ? import <nixpkgs> { }, lib, inputs, ci ? false

, ... }:
with pkgs;
with builtins;
let
  source = callPackage ./_sources/generated.nix {
    inherit fetchFromGitHub fetchurl fetchgit;
  };
  sourcee = callPackage ./_sources/generated.nix {
    inherit fetchFromGitHub fetchurl fetchgit;
  };

  allPkgs = my-pkgs // pkgs // { inherit source sourcee; };
  callPackage = lib.callPackageWith allPkgs;
  my-pkgs = rec {
    # example-docker =
    #   pkgs.dockerTools.buildImage {
    #     name = "hello-docker";
    #     tag = "latest";
    #     created = "now";
    #     runAsRoot = ''
    #       mkdir /data
    #     '';
    #     copyToRoot = pkgs.buildEnv {
    #       name = "image-root";
    #       paths = [
    #         pkgs.coreutils
    #         pkgs.bash
    #         pkgs.vim
    #       ];
    #       pathsToLink = [ "/bin" ];
    #     };

    #     config = {
    #       WorkingDir = "/data";
    #       Env = [ "PATH=${pkgs.coreutils}/bin/" ];
    #       Cmd = [ "${pkgs.coreutils}/bin/cat" "${my-pkgs.example-package}" ];
    #     };
    #   };

    launch = stdenv.mkDerivation (source.launch // {
      installPhase = ''
        mkdir -p $out;
        cp -r . $out;
      '';
    });

    bttc = callPackage ./pkgs/bttc { };
    delivery = callPackage ./pkgs/delivery { };

    oci-arm-host-capacity = (inputs.dream2nix.lib.makeFlakeOutputs {
      pkgs = inputs.dream2nix.inputs.nixpkgs.legacyPackages."x86_64-linux";
      source = inputs.oci-arm-host-capacity-src;
      config.projectRoot = ./.;
    }).packages."x86_64-linux"."hitrov/oci-arm-host-capacity";

    my_cookies = callPackage ./pkgs/python3/my_cookies { };
    epc = callPackage ./pkgs/python3/epc { };
    Flask-SimpleLDAP = callPackage ./pkgs/python3/Flask-SimpleLDAP { };
    #lsp-bridge = callPackage ./emacs/lsp-bridge { };
    copilot-el = callPackage ./pkgs/emacs/copilot { };

    ligature = callPackage ./pkgs/emacs/ligature { };

    org-cv = callPackage ./pkgs/emacs/org-cv { };

    inherit (callPackage ./pkgs/npm/tronbox { nodejs = pkgs.nodejs-14_x; })
      tronbox;

    # vbox = nixos-generators.nixosGenerate {
    #   inherit system;
    #   format = "virtualbox";
    # };
    # amazon = nixos-generators.nixosGenerate {
    #   system = "x86_64-linux";
    #   format = "amazon";
    # };

    # tat = callPackage ./tat { };

    # dotfiles = with pkgs;
    #   stdenv.mkDerivation {
    #     pname = "dotfiles";
    #     version = "0.1.0";
    #     src = ./.;
    #     installPhase = ''
    #       mkdir -p $out/etc;
    #       cp -r . $out/etc;
    #     '';
    #   };
    ldap-passthrough-conf = callPackage ./pkgs/ldap-passthrough-conf { };

    ldap-extra-schemas = callPackage ./pkgs/ldap-extra-schemas { };

    # aws-codedeploy-agent = callPackage ./pkgs/ruby/aws-codedeploy-agent { };
    default = bttc;
    # };
  };
in my-pkgs
