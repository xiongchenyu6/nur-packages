# NUR Overlay - Lazy evaluation to avoid infinite recursion
# This overlay provides packages from the NUR repository
# All package definitions are wrapped in functions to ensure lazy evaluation
final: prev:
let
  inherit (prev) lib;

  # Everything under pkgs/ is discovered from one manifest shared with
  # default.nix and flake.nix, so the three cannot drift apart.
  #
  # `callAll` — not `callAvailable` — on purpose: filtering by meta.platforms
  # would force every package's meta while the overlay is being applied, which
  # is exactly the eager evaluation that caused the infinite recursion
  # described in OVERLAY_FIX.md. Left lazy, a package unsupported on this
  # system throws nixpkgs' own platform error when someone accesses it, which
  # is what the hand-written `throw` branches used to do by hand.
  discoveredPackages = (import ./pkgs/manifest.nix { inherit lib; }).callAll prev.callPackage;

  # Shared by the three LDAP-enabled rebuilds below, which each used to inline
  # an identical copy of this override. Lazy: nothing forces it unless one of
  # those three attributes is accessed.
  cyrusSaslWithLdap = (prev.cyrus_sasl.override { enableLdap = true; }).overrideAttrs (_: {
    postInstall = ''
      ln -sf ${discoveredPackages.ldap-passthrough-conf}/slapd.conf $out/lib/sasl2/
      ln -sf ${discoveredPackages.ldap-passthrough-conf}/smtpd.conf $out/lib/sasl2/
    '';
  });
in
discoveredPackages
// {
  # Core packages (available on all platforms)
  # Each package is defined as a lazy thunk

  librime =
    (prev.librime.override {
      plugins = [
        (prev.callPackage ./_sources/generated.nix {
          inherit (prev) fetchFromGitHub fetchurl fetchgit;
        }).librime-lua.src
      ];
    }).overrideAttrs
      (old: {
        buildInputs = old.buildInputs ++ [ prev.lua5_2 ];
        nativeBuildInputs = old.nativeBuildInputs ++ [
          prev.lua5_2
          prev.pkg-config
        ];
      });

  wrangler = prev.wrangler.overrideAttrs (_: {
    dontCheckForBrokenSymlinks = true;
  });

  # Emacs packages — pkgs/emacs/ holds several definitions rather than one
  # package.nix, so it is wired up by hand.
  emacs-copilot-el = prev.callPackage ./pkgs/emacs/copilot-el/package.nix { };
  emacs-combobulate = prev.callPackage ./pkgs/emacs/combobulate/package.nix { };
  emacs-gptel = prev.callPackage ./pkgs/emacs/gptel/package.nix { };
  emacs-magit-gitflow = prev.callPackage ./pkgs/emacs/magit-gitflow/package.nix { };
  emacs-magit-town = prev.callPackage ./pkgs/emacs/magit-town/package.nix { };
  emacs-org-cv = prev.callPackage ./pkgs/emacs/org-cv/package.nix { };

  # Linux-only rebuilds of nixpkgs packages (not definitions under pkgs/).
  # The platform check stays inside the attribute so it is evaluated at access
  # time, never while the overlay is applied.
  cyrus_sasl_with_ldap =
    if lib.hasSuffix "linux" prev.system then
      cyrusSaslWithLdap
    else
      throw "cyrus_sasl_with_ldap is only available on Linux";

  openldap_with_cyrus_sasl =
    if lib.hasSuffix "linux" prev.system then
      (prev.openldap.overrideAttrs (old: {
        configureFlags = old.configureFlags ++ [
          "--enable-spasswd"
          "--with-cyrus-sasl"
        ];
        doCheck = false;
      })).override
        { cyrus_sasl = cyrusSaslWithLdap; }
    else
      throw "openldap_with_cyrus_sasl is only available on Linux";

  postfix_with_ldap =
    if lib.hasSuffix "linux" prev.system then
      prev.postfix.override { cyrus_sasl = cyrusSaslWithLdap; }
    else
      throw "postfix_with_ldap is only available on Linux";

  sssd_with_sude =
    if lib.hasSuffix "linux" prev.system then
      prev.sssd.override { withSudo = true; }
    else
      throw "sssd_with_sude is only available on Linux";

  sudo_with_sssd =
    if lib.hasSuffix "linux" prev.system then
      prev.sudo.override {
        sssd = prev.sssd.override { withSudo = true; };
        withInsults = true;
        withSssd = true;
      }
    else
      throw "sudo_with_sssd is only available on Linux";

  # Dify packages (require uv2nix; must be provided via the flake overlay or passed explicitly)
  # These are placeholders — actual packages come from the flake's perSystem using uv2nix
  dify-web =
    if lib.hasSuffix "linux" prev.system then
      prev.callPackage ./pkgs/dify/web/package.nix { }
    else
      throw "dify-web is only available on Linux";

  # FCITX5 fix
  fcitx5-configtool = prev.fcitx5-configtool.overrideAttrs (oldAttrs: {
    propagatedBuildInputs = (oldAttrs.propagatedBuildInputs or [ ]) ++ [ prev.libxcb-cursor ];
  });

  # PostgreSQL extensions
  # Augments postgresql{_17,_18}(_jit).pkgs so the new extensions are
  # discoverable via `services.postgresql.extensions = ps: [ ps.pg_plan_filter ];`
  # without rebuilding PostgreSQL itself. Uses the `pkgs.callPackage` scope from
  # the original attribute set so that helpers like `postgresqlBuildExtension`
  # resolve automatically.
  inherit
    (
      let
        extForPg = pg: {
          pg_plan_filter = pg.pkgs.callPackage ./pkgs/pg-extensions/pg_plan_filter/package.nix { };
          pg_hashids = pg.pkgs.callPackage ./pkgs/pg-extensions/pg_hashids/package.nix { };
          index_advisor = pg.pkgs.callPackage ./pkgs/pg-extensions/index_advisor/package.nix { };
        };
        # NixOS's services.postgresql module calls
        # `cfg.package.withJIT.withPackages cfg.extensions`. Inside
        # nixpkgs' `pkgs/servers/sql/postgresql/generic.nix`, both
        # `.pkgs` and `.withPackages` are baked against a `self`
        # fixed-point captured when the derivation was first built —
        # BEFORE our overlay runs. Merging `pg.pkgs = pg.pkgs // newExts`
        # therefore only fixes `pg.pkgs` but NOT the pkgs scope that
        # `pg.withPackages` (or `pg.withJIT.withPackages`) internally
        # evaluates its user function against.
        #
        # Fix: wrap `.withPackages` on each of pg / pg.withJIT /
        # pg.withoutJIT so the extension function sees our extras merged
        # into its `ps` argument. We still extend `.pkgs` so explicit
        # access (e.g. `postgresql18Packages.pg_plan_filter` or
        # `pg.pkgs.pg_plan_filter`) works too.
        extendPg =
          pg:
          let
            newExts = extForPg pg;
            wrap =
              p:
              p
              // {
                pkgs = p.pkgs // newExts;
                withPackages = f: p.withPackages (ps: f (ps // newExts));
              };
          in
          (wrap pg)
          // {
            withJIT = wrap pg.withJIT;
            withoutJIT = wrap pg.withoutJIT;
          };
      in
      {
        postgresql_17 = extendPg prev.postgresql_17;
        postgresql_17_jit = extendPg prev.postgresql_17_jit;
        postgresql_18 = extendPg prev.postgresql_18;
        postgresql_18_jit = extendPg prev.postgresql_18_jit;
      }
    )
    postgresql_17
    postgresql_17_jit
    postgresql_18
    postgresql_18_jit
    ;
}
