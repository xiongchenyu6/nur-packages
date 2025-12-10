{
  lib,
  stdenv,
  fetchFromGitHub,
  php82,
  makeWrapper,
  unzip,
}:

stdenv.mkDerivation rec {
  pname = "hashtopolis-server";
  version = "1.0.0-rainbow4";

  src = fetchFromGitHub {
    owner = "hashtopolis";
    repo = "server";
    rev = "v${version}";
    sha256 = "sha256-LMRrHxdjIgNlECeRY859oU4LdkKm/q2j0b5N6Fjf1mc=";
  };

  nativeBuildInputs = [
    makeWrapper
    unzip
  ];

  buildInputs = [ php82 ];

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
  '';

  installPhase = ''
    runHook preInstall

    # Create output directory structure
    mkdir -p $out/share/hashtopolis/src
    mkdir -p $out/bin

    # Copy server files to src subdirectory (as expected by the PHP server)
    cp -r src/* $out/share/hashtopolis/src/

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
