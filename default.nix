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
  ...
}:
with pkgs;
with builtins;
let
  sources = callPackage ./_sources/generated.nix { inherit fetchFromGitHub fetchurl fetchgit; };
  ldap-passthrough-conf = self.packages.x86_64-linux.ldap-passthrough-conf;
in
rec {
    default = librime;
    librime =
      (pkgs.librime.override {
        plugins = [ sources.librime-lua.src ];

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
  }
