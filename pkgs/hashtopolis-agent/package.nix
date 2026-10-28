{
  pkgs,
  lib,
  stdenv,
  python3,
  makeWrapper,
  p7zip,
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
  pythonEnv = python3.withPackages (
    ps: with ps; [
      requests
      psutil
    ]
  );
in
stdenv.mkDerivation (
  sources.hashtopolis-agent
  // {

    nativeBuildInputs = [ makeWrapper ];

    buildInputs = [ pythonEnv ];

    patches = [ ./native-tools.patch ];

    prePatch = ''
      # Upstream ships CRLF sources; normalize the files patched below.
      sed -i 's/\r$//' htpclient/helpers.py htpclient/binarydownload.py
    '';

    doCheck = true;
    nativeCheckInputs = [ p7zip ];
    checkPhase = ''
      runHook preCheck
      PYTHONPATH=. ${pythonEnv}/bin/python3 ${./test-native-tools.py}
      runHook postCheck
    '';

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

      # Create wrapper script that ensures we're in the working directory
      # and that the log file is writable
      cat > $out/bin/hashtopolis-agent << EOF
      #!${stdenv.shell}

      # Ensure we're in a writable directory (systemd should set this, but be safe)
      if [ -w "." ]; then
        # Current directory is writable, use it
        exec ${pythonEnv}/bin/python3 $out/share/hashtopolis-agent/__main__.py "\$@"
      elif [ -n "\$STATE_DIRECTORY" ] && [ -w "\$STATE_DIRECTORY" ]; then
        # Use systemd's STATE_DIRECTORY if available
        cd "\$STATE_DIRECTORY"
        exec ${pythonEnv}/bin/python3 $out/share/hashtopolis-agent/__main__.py "\$@"
      elif [ -w /var/lib/hashtopolis-agent ]; then
        # Fallback to the standard directory
        cd /var/lib/hashtopolis-agent
        exec ${pythonEnv}/bin/python3 $out/share/hashtopolis-agent/__main__.py "\$@"
      else
        echo "Error: No writable directory found for hashtopolis-agent" >&2
        echo "Current directory: \$(pwd)" >&2
        echo "STATE_DIRECTORY: \$STATE_DIRECTORY" >&2
        exit 1
      fi
      EOF
      chmod +x $out/bin/hashtopolis-agent
      wrapProgram $out/bin/hashtopolis-agent \
        --prefix PATH : ${lib.makeBinPath [ p7zip ]} \
        --add-flags "--disable-update"

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
)
