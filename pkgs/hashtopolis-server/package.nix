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
    # Patch confv2.php to use /var/lib/hashtopolis paths
    # This patches both the hardcoded paths AND the relative paths
    substituteInPlace src/inc/confv2.php \
      --replace '"/usr/local/share/hashtopolis/files"' '"/var/lib/hashtopolis/files/"' \
      --replace '"/usr/local/share/hashtopolis/import"' '"/var/lib/hashtopolis/import/"' \
      --replace '"/usr/local/share/hashtopolis/log"' '"/var/lib/hashtopolis/log/"' \
      --replace '"/usr/local/share/hashtopolis/config"' '"/var/lib/hashtopolis/config/"' \
      --replace 'dirname(__FILE__) . "/../files/"' '"/var/lib/hashtopolis/files/"' \
      --replace 'dirname(__FILE__) . "/../import/"' '"/var/lib/hashtopolis/import/"' \
      --replace 'dirname(__FILE__) . "/../log/"' '"/var/lib/hashtopolis/log/"' \
      --replace 'dirname(__FILE__) . "/../config/"' '"/var/lib/hashtopolis/config/"'
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