{ lib
, stdenv
, fetchFromGitHub
, python3
, makeWrapper
, zip
}:

let
  pythonEnv = python3.withPackages (ps: with ps; [
    requests
    psutil
  ]);
in
stdenv.mkDerivation rec {
  pname = "hashtopolis-agent";
  version = "0.7.4";

  src = fetchFromGitHub {
    owner = "hashtopolis";
    repo = "agent-python";
    rev = "v${version}";
    sha256 = "0z2r34dchdfabn99xsnviskgs9q61pw2ds2r6yw1mzc19xf86arb";
  };

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [ pythonEnv ];

  buildPhase = ''
    runHook preBuild

    # Fix timestamps to avoid zip creation issues
    find . -exec touch -t 198001010000 {} \;

    # Create the agent zip file as expected by Hashtopolis
    # Using zip command instead of python's zipfile module to avoid timestamp issues
    ${zip}/bin/zip -r hashtopolis.zip \
      hashtopolis.py \
      htpclient \
      __main__.py \
      || true

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Install the agent
    mkdir -p $out/share/hashtopolis-agent
    mkdir -p $out/bin

    # Copy the zip file
    cp hashtopolis.zip $out/share/hashtopolis-agent/

    # Create wrapper script
    makeWrapper ${pythonEnv}/bin/python3 $out/bin/hashtopolis-agent \
      --add-flags "$out/share/hashtopolis-agent/hashtopolis.zip"

    runHook postInstall
  '';

  meta = with lib; {
    description = "Python agent for Hashtopolis distributed hashcat tasks";
    homepage = "https://hashtopolis.org";
    license = licenses.gpl3Only;
    maintainers = [ ];
    platforms = platforms.all;
  };
}