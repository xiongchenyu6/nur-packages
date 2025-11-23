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

  postPatch = ''
    # Patch the agent to use system 7z instead of downloading 7zr
    # Skip downloading 7zr binary
    substituteInPlace htpclient/binarydownload.py \
      --replace-fail "if not os.path.isfile(path):" "if False:" \
      --replace-fail "\"./7zr\" + Initialize.get_os_extension() + \" x -otemp prince.7z\"" "\"7z x -otemp prince.7z\"" \
      --replace-fail "f\"7zr{Initialize.get_os_extension()} x -otemp temp.7z\"" "\"7z x -otemp temp.7z\"" \
      --replace-fail "f\"./7zr{Initialize.get_os_extension()} x -otemp temp.7z\"" "\"7z x -otemp temp.7z\"" \
      --replace-fail "f'7zr{Initialize.get_os_extension()} x -o\"{temp_folder}\" \"{zip_file}\"'" "f'7z x -o\"{temp_folder}\" \"{zip_file}\"'" \
      --replace-fail "f\"./7zr{Initialize.get_os_extension()} x -o'{temp_folder}' '{zip_file}'\"" "f\"7z x -o'{temp_folder}' '{zip_file}'\""

    # Also patch files.py for 7zr usage
    substituteInPlace htpclient/files.py \
      --replace-fail "f'7zr{Initialize.get_os_extension()} x -aoa -o\"{files_path}\" -y \"{file_localpath}\"'" "f'7z x -aoa -o\"{files_path}\" -y \"{file_localpath}\"'" \
      --replace-fail "f\"./7zr{Initialize.get_os_extension()} x -aoa -o'{files_path}' -y '{file_localpath}'\"" "f\"7z x -aoa -o'{files_path}' -y '{file_localpath}'\""
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