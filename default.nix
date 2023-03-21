# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage
{ pkgs ? import <nixpkgs> { }, lib, inputs, ... }:
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

    my-mongodb = pkgs.mongodb;

    bttc = callPackage ./pkgs/bttc { };
    delivery = callPackage ./pkgs/delivery { };
    chainlink = callPackage ./pkgs/chainlink { };
    wasmvm = callPackage ./pkgs/wasmvm { };
    gotron-sdk = callPackage ./pkgs/gotron-sdk { };
    oci-arm-host-capacity = (inputs.dream2nix.lib.makeFlakeOutputs {
      pkgs = inputs.dream2nix.inputs.nixpkgs.legacyPackages."x86_64-linux";
      source = inputs.oci-arm-host-capacity-src;
      config.projectRoot = ./.;
      autoProjects = true;
    }).packages."x86_64-linux"."hitrov/oci-arm-host-capacity";

    my_cookies = callPackage ./pkgs/python3/my_cookies { };
    epc = callPackage ./pkgs/python3/epc { };

    Flask-SimpleLDAP = callPackage ./pkgs/python3/Flask-SimpleLDAP { };

    newsapi-python = callPackage ./pkgs/python3/newsapi-python { };

    # chatgpt-wrapper = callPackage ./pkgs/python3/chatgpt-wrapper { };

    copilot-el = callPackage ./pkgs/emacs/copilot { };

    ligature = callPackage ./pkgs/emacs/ligature { };

    org-cv = callPackage ./pkgs/emacs/org-cv { };

    magit-gitflow = callPackage ./pkgs/emacs/magit-gitflow { };

    chatgpt = callPackage ./pkgs/emacs/chatgpt { };

    chatgpt-arcana = callPackage ./pkgs/emacs/chatgpt-arcana { };

    org-ai = callPackage ./pkgs/emacs/org-ai { };

    aiac = callPackage ./pkgs/aiac { };

    corfu-english-helper = callPackage ./pkgs/emacs/corfu-english-helper { };

    # tiktoken = callPackage ./pkgs/python3/tiktoken { };

    # magit-town = callPackage ./pkgs/emacs/magit-town { };

    inherit (callPackage ./pkgs/npm { }) tronbox solium;

    amazon-cloudwatch-agent = callPackage ./pkgs/amazon-cloudwatch-agent { };

    nixops-fixed = callPackage ./pkgs/nixops-fixed { };

    java-tron = callPackage ./pkgs/java-tron { };

    tron-eventquery = callPackage ./pkgs/tron-eventquery { };

    my-ferretdb = callPackage ./pkgs/ferretdb { };

    gptcommit = callPackage ./pkgs/gptcommit { };

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

    codedeploy-agent = callPackage ./pkgs/ruby/codedeploy-agent { };
    default = bttc;

    cyrus_sasl_with_ldap =
      (pkgs.cyrus_sasl.override { enableLdap = true; }).overrideAttrs (_: {
        postInstall = ''
          ln -sf ${ldap-passthrough-conf}/slapd.conf $out/lib/sasl2/
          ln -sf ${ldap-passthrough-conf}/smtpd.conf $out/lib/sasl2/
        '';
      });

    openldap_with_cyrus_sasl = (pkgs.openldap.overrideAttrs (old: {
      configureFlags = old.configureFlags
        ++ [ "--enable-spasswd" "--with-cyrus-sasl" ];
      doCheck = false;
    })).override { cyrus_sasl = cyrus_sasl_with_ldap; };

    postfix = pkgs.postfix.override { cyrus_sasl = cyrus_sasl_with_ldap; };

    sssd = pkgs.sssd.override { withSudo = true; };

    krb5 = pkgs.krb5.overrideAttrs (old: {
      configureFlags = old.configureFlags
        ++ (if (old.pname == "libkrb5") then [ ] else [ "--with-ldap" ]);
    });

    sudo_with_sssd = pkgs.sudo.override {
      sssd = sssd;
      withInsults = true;
      withSssd = true;
    };
  };
in my-pkgs
