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
    # No build needed for Python script
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    # Install the agent
    mkdir -p $out/share/hashtopolis-agent
    mkdir -p $out/bin

    # Copy all agent files
    cp -r * $out/share/hashtopolis-agent/

    # Create wrapper script that doesn't change directory
    # The service will set the working directory appropriately
    cat > $out/bin/hashtopolis-agent << EOF
    #!${stdenv.shell}
    exec ${pythonEnv}/bin/python3 $out/share/hashtopolis-agent/__main__.py "\$@"
    EOF
    chmod +x $out/bin/hashtopolis-agent

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