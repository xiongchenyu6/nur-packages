{
  lib,
  php82,
  fetchFromGitHub,
  makeWrapper,
  stdenv,
}:

php82.buildComposerProject2 {
  pname = "hashtopolis-server";
  version = "1.0.0";

  src = fetchFromGitHub {
    owner = "hashtopolis";
    repo = "server";
    rev = "v1.0.0-rainbow4";
    hash = "sha256-LMRrHxdjIgNlECeRY859oU4LdkKm/q2j0b5N6Fjf1mc=";
  };

  vendorHash = if stdenv.hostPlatform.isAarch64 
    then "sha256-/1P7Sc0Kq+qXTiOh64YjSbI96U/cg2Wwyk4YPo+iqAM="
    else "sha256-oNhs39uECAU0xIlTJEdsSnNjPtzBNK+I0bKR2x27v3w=";

  composerNoDev = true;

  nativeBuildInputs = [ makeWrapper ];

  postPatch = ''
    # Add support for HASHTOPOLIS_CONFIG_PATH environment variable
    # Insert it at line 42, right after the LOG_PATH check
    cat > patch.tmp << 'EOF'
  if (getenv('HASHTOPOLIS_CONFIG_PATH') !== false) {
    $DIRECTORIES["config"] = getenv('HASHTOPOLIS_CONFIG_PATH');
  }
EOF
    sed -i '42r patch.tmp' src/inc/confv2.php
    rm patch.tmp

    # Patch Lock.class.php to use environment variable for locks directory
    substituteInPlace src/inc/utils/Lock.class.php \
      --replace 'dirname(__FILE__) . "/locks/"' '(getenv("HASHTOPOLIS_LOCKS_PATH") ?: dirname(__FILE__) . "/locks/") . "/"'

    # Patch LockUtils.class.php deleteLockFile method  
    substituteInPlace src/inc/utils/LockUtils.class.php \
      --replace 'dirname(__FILE__) . "/locks/"' '(getenv("HASHTOPOLIS_LOCKS_PATH") ?: dirname(__FILE__) . "/locks/") . "/"'
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
    cp env.example $out/share/hashtopolis/.env.example

    # Create wrapper script for running the server
    makeWrapper ${php82}/bin/php $out/bin/hashtopolis-server \
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
}
