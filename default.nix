# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage
{
  self,
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  ...
}:
let
  sources = pkgs.callPackage ./_sources/generated.nix { 
    inherit (pkgs) fetchFromGitHub fetchurl fetchgit; 
  };
  
  # Check if we're on Linux
  isLinux = pkgs.stdenv.isLinux;
  
  # Build ldap-passthrough-conf directly from the package definition (only needed on Linux)
  ldap-passthrough-conf = if isLinux 
    then pkgs.callPackage ./pkgs/ldap-passthrough-conf/package.nix { }
    else null;

  # Linux-only packages
  linuxPackages = lib.optionalAttrs isLinux {
    cyrus_sasl_with_ldap = (pkgs.cyrus_sasl.override { enableLdap = true; }).overrideAttrs (_: {
      postInstall = ''
        ln -sf ${ldap-passthrough-conf}/slapd.conf $out/lib/sasl2/
        ln -sf ${ldap-passthrough-conf}/smtpd.conf $out/lib/sasl2/
      '';
    });

    openldap_with_cyrus_sasl =
      let
        cyrus_sasl_with_ldap_pkg = (pkgs.cyrus_sasl.override { enableLdap = true; }).overrideAttrs (_: {
          postInstall = ''
            ln -sf ${ldap-passthrough-conf}/slapd.conf $out/lib/sasl2/
            ln -sf ${ldap-passthrough-conf}/smtpd.conf $out/lib/sasl2/
          '';
        });
      in
      (pkgs.openldap.overrideAttrs (old: {
        configureFlags = old.configureFlags ++ [
          "--enable-spasswd"
          "--with-cyrus-sasl"
        ];
        doCheck = false;
      })).override
        { cyrus_sasl = cyrus_sasl_with_ldap_pkg; };

    postfix_with_ldap =
      let
        cyrus_sasl_with_ldap_pkg = (pkgs.cyrus_sasl.override { enableLdap = true; }).overrideAttrs (_: {
          postInstall = ''
            ln -sf ${ldap-passthrough-conf}/slapd.conf $out/lib/sasl2/
            ln -sf ${ldap-passthrough-conf}/smtpd.conf $out/lib/sasl2/
          '';
        });
      in
      pkgs.postfix.override { cyrus_sasl = cyrus_sasl_with_ldap_pkg; };

    sssd_with_sude = pkgs.sssd.override { withSudo = true; };

    sudo_with_sssd =
      let
        sssd_pkg = pkgs.sssd.override { withSudo = true; };
      in
      pkgs.sudo.override {
        sssd = sssd_pkg;
        withInsults = true;
        withSssd = true;
      };
  };

in
{
  librime =
    (pkgs.librime.override {
      plugins = [ sources.librime-lua.src ];
    }).overrideAttrs
      (old: {
        buildInputs = old.buildInputs ++ [ pkgs.lua ];
      });
  
  default = pkgs.librime.override {
    plugins = [ sources.librime-lua.src ];
  };

  wrangler = pkgs.wrangler.overrideAttrs (old: {
    dontCheckForBrokenSymlinks = true;
  });

  # Hashtopolis packages
  hashtopolis-server = if isLinux
    then pkgs.callPackage ./pkgs/hashtopolis-server/package.nix { }
    else null;

  hashtopolis-agent = pkgs.callPackage ./pkgs/hashtopolis-agent/package.nix { };
} // linuxPackages
