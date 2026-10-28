{
  pkgs,
  lib,
  php83,
  makeWrapper,
  sqlx-cli,
}:
let
  sources = import ../../_sources/generated.nix {
    inherit (pkgs)
      fetchgit
      fetchFromGitHub
      fetchurl
      dockerTools
      ;
  };
in
php83.buildComposerProject2 (
  sources.hashtopolis-server
  // {
    vendorHash = "sha256-/kqEBEGn/VfrDDBtVGGMO53IPh6W8YTRAkC3pybLm8c=";
    composerNoDev = true;
    nativeBuildInputs = [ makeWrapper ];

    postPatch = ''
      substituteInPlace src/inc/utils/Lock.php src/inc/utils/LockUtils.php \
        --replace-fail 'dirname(__FILE__) . "/locks/"' '(getenv("HASHTOPOLIS_LOCKS_PATH") ?: dirname(__FILE__) . "/locks/") . "/"'
      substituteInPlace src/inc/utils/MigrationUtils.php \
        --replace-fail '/usr/bin/sqlx' '${sqlx-cli}/bin/sqlx'
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/hashtopolis $out/bin
      cp -r src vendor doc composer.json composer.lock $out/share/hashtopolis/
      cp ${./router.php} $out/share/hashtopolis/router.php
      # init.php loads every model PHP file; the development generator must not
      # run at startup and attempt to rewrite the immutable release models.
      rm $out/share/hashtopolis/src/dba/models/generator.php
      makeWrapper ${php83}/bin/php $out/bin/hashtopolis-server \
        --add-flags "-S 127.0.0.1:8080 -t $out/share/hashtopolis/src $out/share/hashtopolis/router.php"
      runHook postInstall
    '';

    meta = {
      description = "A multi-platform client-server tool for distributing hashcat tasks";
      homepage = "https://hashtopolis.org";
      license = lib.licenses.gpl3Only;
      platforms = lib.platforms.linux;
    };
  }
)
