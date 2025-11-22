{ lib
, stdenv
, fetchFromGitHub
, php82
, mariadb
, makeWrapper
, unzip
}:

stdenv.mkDerivation rec {
  pname = "hashtopolis-server";
  version = "0.14.6";

  src = fetchFromGitHub {
    owner = "hashtopolis";
    repo = "server";
    rev = "v${version}";
    sha256 = "0z2p63c41bj93m2fmvan8j21sgvzfv28bz4n0kv17qgh83nb19wa";
  };

  nativeBuildInputs = [ makeWrapper unzip ];

  buildInputs = [ php82 ];

  postPatch = ''
    # Add support for HASHTOPOLIS_CONFIG_PATH environment variable
    # The application doesn't have this by default, so we add it
    cat >> src/inc/confv2.php << 'PHP_PATCH'

    // Added by Nix to support config path environment variable
    if (isset($DIRECTORIES) && getenv('HASHTOPOLIS_CONFIG_PATH') !== false) {
      $DIRECTORIES["config"] = getenv('HASHTOPOLIS_CONFIG_PATH');
    }
    PHP_PATCH
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