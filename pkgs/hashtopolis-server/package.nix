{
  pkgs,
  lib,
  php83,
  makeWrapper,
  stdenv,
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
  version = builtins.replaceStrings [ "-rainbow" ] [ "-rc" ] sources.hashtopolis-server.version;

  vendorHash = "sha256-KobiZlzJjL6nOsxmbndnNxE5a9ElLvU+ehdnvcRqtxo=";

  composerNoDev = true;

  composerStrictValidation = false;

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    # Patch Lock.php to use environment variable for locks directory
    substituteInPlace src/inc/utils/Lock.php \
      --replace 'dirname(__FILE__) . "/locks/"' '(getenv("HASHTOPOLIS_LOCKS_PATH") ?: dirname(__FILE__) . "/locks/") . "/"'

    # Patch LockUtils.php deleteLockFile method
    substituteInPlace src/inc/utils/LockUtils.php \
      --replace 'dirname(__FILE__) . "/locks/"' '(getenv("HASHTOPOLIS_LOCKS_PATH") ?: dirname(__FILE__) . "/locks/") . "/"'

    # Ensure update.php loads the Composer autoloader (needed for Composer\Semver\Comparator)
    sed -i '2a require_once(dirname(__FILE__) . "/../../vendor/autoload.php");' src/install/updates/update.php
  '';

  installPhase = ''
    runHook preInstall

    # Create output directory structure
    mkdir -p $out/share/hashtopolis/src
    mkdir -p $out/share/hashtopolis/vendor
    mkdir -p $out/bin

    # Copy server files to src subdirectory (as expected by the PHP server)
    cp -r src/* $out/share/hashtopolis/src/

    # Copy vendor directory with Composer dependencies
    cp -r vendor/* $out/share/hashtopolis/vendor/

    # Copy additional files
    cp -r doc $out/share/hashtopolis/
    cp env.mysql.example $out/share/hashtopolis/.env.mysql.example
    cp env.postgres.example $out/share/hashtopolis/.env.postgres.example

    # Create wrapper script for running the server
    makeWrapper ${php83}/bin/php $out/bin/hashtopolis-server \
      --add-flags "-S 0.0.0.0:8080 -t $out/share/hashtopolis/src"

    runHook postInstall
  '';

  meta = with lib; {
    description = "A multi-platform client-server tool for distributing hashcat tasks";
    homepage = "https://hashtopolis.org";
    license = licenses.gpl3Only;
    maintainers = [ ];
    platforms = platforms.linux;
  };
})
