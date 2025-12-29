# NUR Overlay - Lazy evaluation to avoid infinite recursion
# This overlay provides packages from the NUR repository
# All package definitions are wrapped in functions to ensure lazy evaluation
final: prev:
let
  inherit (prev) lib;
in
{
  # Core packages (available on all platforms)
  # Each package is defined as a lazy thunk
  
  librime = (prev.librime.override {
    plugins = [
      (prev.callPackage ./_sources/generated.nix {
        inherit (prev) fetchFromGitHub fetchurl fetchgit;
      }).librime-lua.src
    ];
  }).overrideAttrs (old: {
    buildInputs = old.buildInputs ++ [ prev.lua5_2 ];
    nativeBuildInputs = old.nativeBuildInputs ++ [ prev.lua5_2 prev.pkg-config ];
  });
  
  wrangler = prev.wrangler.overrideAttrs (old: {
    dontCheckForBrokenSymlinks = true;
  });
  
  # Emacs packages
  emacs-copilot-el = prev.callPackage ./pkgs/emacs/copilot-el/package.nix { };
  emacs-combobulate = prev.callPackage ./pkgs/emacs/combobulate/package.nix { };
  emacs-gptel = prev.callPackage ./pkgs/emacs/gptel/package.nix { };
  emacs-magit-gitflow = prev.callPackage ./pkgs/emacs/magit-gitflow/package.nix { };
  emacs-magit-town = prev.callPackage ./pkgs/emacs/magit-town/package.nix { };
  emacs-org-cv = prev.callPackage ./pkgs/emacs/org-cv/package.nix { };
  
  # Linux-only packages (conditionally included)
  cyrus_sasl_with_ldap = 
    if lib.hasSuffix "linux" prev.system then
      let
        ldap-passthrough-conf = prev.callPackage ./pkgs/ldap-passthrough-conf/package.nix { };
      in
      (prev.cyrus_sasl.override { enableLdap = true; }).overrideAttrs (_: {
        postInstall = ''
          ln -sf ${ldap-passthrough-conf}/slapd.conf $out/lib/sasl2/
          ln -sf ${ldap-passthrough-conf}/smtpd.conf $out/lib/sasl2/
        '';
      })
    else
      throw "cyrus_sasl_with_ldap is only available on Linux";
  
  openldap_with_cyrus_sasl =
    if lib.hasSuffix "linux" prev.system then
      let
        ldap-passthrough-conf = prev.callPackage ./pkgs/ldap-passthrough-conf/package.nix { };
        cyrus_sasl_with_ldap_pkg = (prev.cyrus_sasl.override { enableLdap = true; }).overrideAttrs (_: {
          postInstall = ''
            ln -sf ${ldap-passthrough-conf}/slapd.conf $out/lib/sasl2/
            ln -sf ${ldap-passthrough-conf}/smtpd.conf $out/lib/sasl2/
          '';
        });
      in
      (prev.openldap.overrideAttrs (old: {
        configureFlags = old.configureFlags ++ [
          "--enable-spasswd"
          "--with-cyrus-sasl"
        ];
        doCheck = false;
      })).override { cyrus_sasl = cyrus_sasl_with_ldap_pkg; }
    else
      throw "openldap_with_cyrus_sasl is only available on Linux";
  
  postfix_with_ldap =
    if lib.hasSuffix "linux" prev.system then
      let
        ldap-passthrough-conf = prev.callPackage ./pkgs/ldap-passthrough-conf/package.nix { };
        cyrus_sasl_with_ldap_pkg = (prev.cyrus_sasl.override { enableLdap = true; }).overrideAttrs (_: {
          postInstall = ''
            ln -sf ${ldap-passthrough-conf}/slapd.conf $out/lib/sasl2/
            ln -sf ${ldap-passthrough-conf}/smtpd.conf $out/lib/sasl2/
          '';
        });
      in
      prev.postfix.override { cyrus_sasl = cyrus_sasl_with_ldap_pkg; }
    else
      throw "postfix_with_ldap is only available on Linux";
  
  sssd_with_sude =
    if lib.hasSuffix "linux" prev.system then
      prev.sssd.override { withSudo = true; }
    else
      throw "sssd_with_sude is only available on Linux";
  
  sudo_with_sssd =
    if lib.hasSuffix "linux" prev.system then
      let
        sssd_pkg = prev.sssd.override { withSudo = true; };
      in
      prev.sudo.override {
        sssd = sssd_pkg;
        withInsults = true;
        withSssd = true;
      }
    else
      throw "sudo_with_sssd is only available on Linux";
  
  ldap-passthrough-conf =
    if lib.hasSuffix "linux" prev.system then
      prev.callPackage ./pkgs/ldap-passthrough-conf/package.nix { }
    else
      throw "ldap-passthrough-conf is only available on Linux";
  
  # Packages from pkgs/ directory (automatically discovered)
  # Only include packages that are compatible with the current platform
  
  gotron-sdk = prev.callPackage ./pkgs/gotron-sdk/package.nix { };
  helmify = prev.callPackage ./pkgs/helmify/package.nix { };
  korb = prev.callPackage ./pkgs/korb/package.nix { };
  ldap-extra-schemas = prev.callPackage ./pkgs/ldap-extra-schemas/package.nix { };
  my2sql = prev.callPackage ./pkgs/my2sql/package.nix { };
  
  # Linux-only packages from pkgs/
  falcon-sensor =
    if lib.hasSuffix "linux" prev.system then
      prev.callPackage ./pkgs/falcon-sensor/package.nix { }
    else
      throw "falcon-sensor is only available on Linux";

  feishu-lark =
    if lib.hasSuffix "linux" prev.system then
      prev.callPackage ./pkgs/feishu-lark/package.nix { }
    else
      throw "feishu-lark is only available on Linux";
  
  haystack-editor =
    if lib.hasSuffix "linux" prev.system then
      prev.callPackage ./pkgs/haystack-editor/package.nix { }
    else
      throw "haystack-editor is only available on Linux";
  
  record_screen =
    if lib.hasSuffix "linux" prev.system then
      prev.callPackage ./pkgs/record_screen/package.nix { }
    else
      throw "record_screen is only available on Linux";
  
  sui =
    if lib.hasSuffix "linux" prev.system then
      prev.callPackage ./pkgs/sui/package.nix { }
    else
      throw "sui is only available on Linux";

  # Hashtopolis packages
  hashtopolis-server =
    if lib.hasSuffix "linux" prev.system then
      prev.callPackage ./pkgs/hashtopolis-server/package.nix { }
    else
      throw "hashtopolis-server is only available on Linux";

  hashtopolis-agent = prev.callPackage ./pkgs/hashtopolis-agent/package.nix { };

  # FCITX5 fix
  fcitx5-configtool = prev.fcitx5-configtool.overrideAttrs (oldAttrs: {
    propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or []) ++ [ prev.libxcb-cursor ];
  });
}

