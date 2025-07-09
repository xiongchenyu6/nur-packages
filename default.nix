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
let
  sources = pkgs.callPackage ./_sources/generated.nix { 
    inherit (pkgs) fetchFromGitHub fetchurl fetchgit; 
  };
  # Build ldap-passthrough-conf directly from the package definition
  ldap-passthrough-conf = pkgs.callPackage ./pkgs/ldap-passthrough-conf/package.nix { };

  # Helper function to check if a package is available on the current platform
  isPackageAvailable = pkg: 
    let
      meta = pkg.meta or {};
      platforms = meta.platforms or [];
      badPlatforms = meta.badPlatforms or [];
      currentSystem = pkgs.system;
    in
      (platforms == [] || builtins.elem currentSystem platforms) &&
      !builtins.elem currentSystem badPlatforms;

  # Helper to conditionally include packages based on platform availability
  optionalPackage = name: pkg: 
    if isPackageAvailable pkg then { ${name} = pkg; } else {};

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

  wrangler = (
    pkgs.wrangler.overrideAttrs (old: {
      dontCheckForBrokenSymlinks = true;
    })
  );
} 
// optionalPackage "cyrus_sasl_with_ldap" ((pkgs.cyrus_sasl.override { enableLdap = true; }).overrideAttrs (_: {
  postInstall = ''
    ln -sf ${ldap-passthrough-conf}/slapd.conf $out/lib/sasl2/
    ln -sf ${ldap-passthrough-conf}/smtpd.conf $out/lib/sasl2/
  '';
}))
// optionalPackage "openldap_with_cyrus_sasl" (
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
    { cyrus_sasl = cyrus_sasl_with_ldap_pkg; }
)
// optionalPackage "postfix_with_ldap" (
  let
    cyrus_sasl_with_ldap_pkg = (pkgs.cyrus_sasl.override { enableLdap = true; }).overrideAttrs (_: {
      postInstall = ''
        ln -sf ${ldap-passthrough-conf}/slapd.conf $out/lib/sasl2/
        ln -sf ${ldap-passthrough-conf}/smtpd.conf $out/lib/sasl2/
      '';
    });
  in
  pkgs.postfix.override { cyrus_sasl = cyrus_sasl_with_ldap_pkg; }
)
// optionalPackage "sssd_with_sude" (pkgs.sssd.override { withSudo = true; })
// optionalPackage "sudo_with_sssd" (
  let
    sssd_pkg = pkgs.sssd.override { withSudo = true; };
  in
  pkgs.sudo.override {
    sssd = sssd_pkg;
    withInsults = true;
    withSssd = true;
  }
)
