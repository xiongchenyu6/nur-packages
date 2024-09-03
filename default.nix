# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage
{
  pkgs ? import <nixpkgs> { },
  lib,
  inputs,
  ...
}:
with pkgs;
with builtins;
let
  source = callPackage ./_sources/generated.nix { inherit fetchFromGitHub fetchurl fetchgit; };
  sourcee = callPackage ./_sources/generated.nix { inherit fetchFromGitHub fetchurl fetchgit; };

  allPkgs = my-pkgs // pkgs // { inherit source sourcee; };
  callPackage = lib.callPackageWith allPkgs;
  my-pkgs = rec {
    launch = stdenv.mkDerivation (
      source.launch
      // {
        installPhase = ''
          mkdir -p $out;
          cp -r . $out;
        '';
      }
    );

    pg-ldap-sync = callPackage ./pkgs/pg-ldap-sync { };

    helmify = callPackage ./pkgs/helmify { };

    bttc = callPackage ./pkgs/bttc { };

    # glab = callPackage ./pkgs/glab { };

    # discourse-hb = callPackage ./pkgs/discourse { };

    my2sql = callPackage ./pkgs/my2sql { };

    # delivery = callPackage ./pkgs/delivery { };

    gotron-sdk = callPackage ./pkgs/gotron-sdk { };

    korb = callPackage ./pkgs/korb { };

    # oci-arm-host-capacity = (inputs.dream2nix.lib.makeFlakeOutputs {
    #   pkgs = inputs.dream2nix.inputs.nixpkgs.legacyPackages."x86_64-linux";
    #   source = inputs.oci-arm-host-capacity-src;
    #   config.projectRoot = ./.;
    #   autoProjects = true;
    # }).packages."x86_64-linux"."hitrov/oci-arm-host-capacity";

    # my_cookies = callPackage ./pkgs/python3/my_cookies { };

    #epc = callPackage ./pkgs/python3/epc { };

    #newsapi-python = callPackage ./pkgs/python3/newsapi-python { };

    copilot-el = callPackage ./pkgs/emacs/copilot { };

    copilot-chat = callPackage ./pkgs/emacs/copilot-chat { };

    # org-cv = callPackage ./pkgs/emacs/org-cv { };

    combobulate = callPackage ./pkgs/emacs/combobulate { };

    magit-gitflow = callPackage ./pkgs/emacs/magit-gitflow { };

    magit-town = callPackage ./pkgs/emacs/magit-town { };

    inherit (callPackage ./pkgs/npm { }) tronbox solium;

    java-tron = callPackage ./pkgs/java-tron { };

    tron-eventquery = callPackage ./pkgs/tron-eventquery { };

    ldap-passthrough-conf = callPackage ./pkgs/ldap-passthrough-conf { };

    ldap-extra-schemas = callPackage ./pkgs/ldap-extra-schemas { };

    default = bttc;

    feishu-lark = callPackage ./pkgs/feishu-lark { };

    cursor = callPackage ./pkgs/cursor { };

    haystack-editor = callPackage ./pkgs/haystack-editor { };
    librime =
      (pkgs.librime.override {
        plugins = [ source.librime-lua.src ];

      }).overrideAttrs
        (old: {
          buildInputs = old.buildInputs ++ [ pkgs.lua ];
        });

    cyrus_sasl_with_ldap = (pkgs.cyrus_sasl.override { enableLdap = true; }).overrideAttrs (_: {
      postInstall = ''
        ln -sf ${ldap-passthrough-conf}/slapd.conf $out/lib/sasl2/
        ln -sf ${ldap-passthrough-conf}/smtpd.conf $out/lib/sasl2/
      '';
    });

    openldap_with_cyrus_sasl =
      (pkgs.openldap.overrideAttrs (old: {
        configureFlags = old.configureFlags ++ [
          "--enable-spasswd"
          "--with-cyrus-sasl"
        ];
        doCheck = false;
      })).override
        { cyrus_sasl = cyrus_sasl_with_ldap; };

    postfix_with_ldap = pkgs.postfix.override { cyrus_sasl = cyrus_sasl_with_ldap; };

    sssd_with_sude = pkgs.sssd.override { withSudo = true; };

    # krb5_with_ldap = pkgs.krb5.overrideAttrs (old: {
    #   configureFlags = old.configureFlags
    #     ++ (if (old.pname == "libkrb5") then [ ] else [ "--with-ldap" ]);
    # });

    sudo_with_sssd = pkgs.sudo.override {
      sssd = sssd;
      withInsults = true;
      withSssd = true;
    };
  };
in
my-pkgs
