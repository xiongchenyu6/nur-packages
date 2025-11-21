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

  installPhase = ''
    runHook preInstall

    # Create output directory structure
    mkdir -p $out/share/hashtopolis
    mkdir -p $out/bin

    # Copy server files
    cp -r src/* $out/share/hashtopolis/

    # Copy additional files
    cp -r doc $out/share/hashtopolis/
    cp env.example $out/share/hashtopolis/.env.example

    # Create wrapper script for running the server
    makeWrapper ${php82}/bin/php $out/bin/hashtopolis-server \
      --add-flags "-S 0.0.0.0:8080 -t $out/share/hashtopolis"

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