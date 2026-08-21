# This file describes your repository contents.
# It should return a set of nix derivations
# and optionally the special attributes `lib`, `modules` and `overlays`.
# It should NOT import <nixpkgs>. Instead, you should take pkgs as an argument.
# Having pkgs default to <nixpkgs> is fine though, and it lets you use short
# commands such as:
#     nix-build -A mypackage
{
  pkgs ? import <nixpkgs> { },
  lib ? pkgs.lib,
  # `self` used to be a required argument here even though nothing read it,
  # which broke both `nix-build -A <pkg>` — the invocation this file's own
  # header advertises — and NUR, which evaluates `import ./. { inherit pkgs; }`.
  # The trailing ellipsis still accepts it from flake.nix.
  ...
}:
let
  sources = pkgs.callPackage ./_sources/generated.nix {
    inherit (pkgs) fetchFromGitHub fetchurl fetchgit;
  };

  # Everything under pkgs/ comes from one manifest, so this file cannot drift
  # out of sync with overlay.nix and flake.nix the way three hand-written lists
  # did. Packages whose meta.platforms excludes the current system are dropped
  # rather than set to null, so referencing one fails loudly.
  manifest = import ./pkgs/manifest.nix { inherit lib; };
  discoveredPackages = manifest.callAvailable pkgs.stdenv.hostPlatform pkgs.callPackage;

  isLinux = pkgs.stdenv.hostPlatform.isLinux;

  # Shared by the three LDAP-enabled rebuilds below, which each used to inline
  # an identical copy of this override.
  cyrusSaslWithLdap = (pkgs.cyrus_sasl.override { enableLdap = true; }).overrideAttrs (_: {
    postInstall = ''
      ln -sf ${discoveredPackages.ldap-passthrough-conf}/slapd.conf $out/lib/sasl2/
      ln -sf ${discoveredPackages.ldap-passthrough-conf}/smtpd.conf $out/lib/sasl2/
    '';
  });

  # Linux-only rebuilds of nixpkgs packages (not definitions under pkgs/).
  linuxPackages = lib.optionalAttrs isLinux {
    cyrus_sasl_with_ldap = cyrusSaslWithLdap;

    openldap_with_cyrus_sasl =
      (pkgs.openldap.overrideAttrs (old: {
        configureFlags = old.configureFlags ++ [
          "--enable-spasswd"
          "--with-cyrus-sasl"
        ];
        doCheck = false;
      })).override
        { cyrus_sasl = cyrusSaslWithLdap; };

    postfix_with_ldap = pkgs.postfix.override { cyrus_sasl = cyrusSaslWithLdap; };

    sssd_with_sude = pkgs.sssd.override { withSudo = true; };

    sudo_with_sssd = pkgs.sudo.override {
      sssd = pkgs.sssd.override { withSudo = true; };
      withInsults = true;
      withSssd = true;
    };
  };

  # Define librime with lua5_2 support
  librime =
    (pkgs.librime.override {
      plugins = [ sources.librime-lua.src ];
    }).overrideAttrs
      (old: {
        buildInputs = old.buildInputs ++ [ pkgs.lua5_2 ];
        nativeBuildInputs = old.nativeBuildInputs ++ [
          pkgs.lua5_2
          pkgs.pkg-config
        ];
      });
in
discoveredPackages
// linuxPackages
// {
  inherit librime;

  default = librime;

  wrangler = pkgs.wrangler.overrideAttrs (_: {
    dontCheckForBrokenSymlinks = true;
  });

  # Dify packages (built via flake.nix perSystem with uv2nix, not directly callable here)
  # Use `nix build .#dify-api` and `nix build .#dify-web` instead
}
