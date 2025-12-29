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
    # Add necessary imports at the top (shutil for which() function)
    substituteInPlace htpclient/binarydownload.py \
      --replace-fail "import os.path" $'import os\nimport os.path\nimport shutil'

    # Skip downloading 7zr binary - always use system 7z
    substituteInPlace htpclient/binarydownload.py \
      --replace-fail "if not os.path.isfile(path):" "if False:  # Patched: always use system 7z"

    # Replace 7zr commands with 7z
    substituteInPlace htpclient/binarydownload.py \
      --replace-fail "\"./7zr\" + Initialize.get_os_extension() + \" x -otemp prince.7z\"" "\"7z x -aoa -y -otemp prince.7z\"" \
      --replace-fail "f\"7zr{Initialize.get_os_extension()} x -otemp temp.7z\"" "\"7z x -aoa -y -otemp temp.7z\"" \
      --replace-fail "f\"./7zr{Initialize.get_os_extension()} x -otemp temp.7z\"" "\"7z x -aoa -y -otemp temp.7z\"" \
      --replace-fail "f'7zr{Initialize.get_os_extension()} x -o\"{temp_folder}\" \"{zip_file}\"'" "f'7z x -aoa -y -o\"{temp_folder}\" \"{zip_file}\"'" \
      --replace-fail "f\"./7zr{Initialize.get_os_extension()} x -o'{temp_folder}' '{zip_file}'\"" "f\"7z x -aoa -y -o'{temp_folder}' '{zip_file}'\"" \
      --replace-fail "os.rename(Path('temp', name), path)" "shutil.move(Path('temp', name), path)"

    # Also patch files.py for 7zr usage
    substituteInPlace htpclient/files.py \
      --replace-fail "f'7zr{Initialize.get_os_extension()} x -aoa -o\"{files_path}\" -y \"{file_localpath}\"'" "f'7z x -aoa -o\"{files_path}\" -y \"{file_localpath}\"'" \
      --replace-fail "f\"./7zr{Initialize.get_os_extension()} x -aoa -o'{files_path}' -y '{file_localpath}'\"" "f\"7z x -aoa -o'{files_path}' -y '{file_localpath}'\""

    # Patch check_version method to support native hashcat
    # Replace the entire check_version method with one that checks use-native-hashcat config
    substituteInPlace htpclient/binarydownload.py \
      --replace-fail "def check_version(self, cracker_id):" $'def check_version(self, cracker_id):\n        # Native hashcat support patch\n        use_native = self.config.get_value(\'use-native-hashcat\')\n        native_path = self.config.get_value(\'native-hashcat-path\')\n        logging.info(f\'check_version called: cracker_id={cracker_id}, use_native={use_native}, native_path={native_path}\')\n        if use_native:\n            logging.info(\'Using native hashcat (use-native-hashcat=true)\')\n            path = Path(self.config.get_value(\'crackers-path\'), str(cracker_id))\n            logging.info(f\'Crackers path: {path}\')\n            # Query server for version info (still needed for metadata)\n            query = copy_and_set_token(dict_downloadBinary, self.config.get_value(\'token\'))\n            query[\'type\'] = \'cracker\'\n            query[\'binaryVersionId\'] = cracker_id\n            req = JsonRequest(query)\n            ans = req.execute()\n            if ans is None:\n                logging.error(\'Failed to get cracker info from server!\')\n                sleep(5)\n                return False\n            elif ans[\'response\'] != \'SUCCESS\':\n                logging.error(\'Getting cracker info failed: \' + str(ans))\n                sleep(5)\n                return False\n            self.last_version = ans\n            # Create directory if needed\n            if not os.path.isdir(path):\n                os.makedirs(path)\n                logging.info(f\'Created directory: {path}\')\n            # Find system hashcat\n            hashcat_bin = None\n            if native_path and os.path.isfile(native_path):\n                hashcat_bin = native_path\n                logging.info(f\'Using configured native hashcat path: {native_path}\')\n            else:\n                hashcat_bin = shutil.which(\'hashcat\')\n                logging.info(f\'shutil.which(hashcat) returned: {hashcat_bin}\')\n                if not hashcat_bin:\n                    for p in [\'/run/current-system/sw/bin/hashcat\', \'/usr/bin/hashcat\', \'/usr/local/bin/hashcat\']:\n                        if os.path.isfile(p):\n                            hashcat_bin = p\n                            logging.info(f\'Found hashcat at fallback path: {p}\')\n                            break\n            if not hashcat_bin:\n                logging.error(\'Native hashcat not found! Set native-hashcat-path or ensure hashcat is in PATH\')\n                return False\n            logging.info(f\'Found native hashcat at: {hashcat_bin}\')\n            # Create hashcat symlink\n            hashcat_link = path / \'hashcat\'\n            logging.info(f\'Processing hashcat link: {hashcat_link}\')\n            try:\n                if os.path.islink(hashcat_link):\n                    logging.info(f\'Removing existing symlink: {hashcat_link}\')\n                    os.unlink(hashcat_link)\n                elif os.path.exists(hashcat_link):\n                    logging.info(f\'Removing existing file: {hashcat_link}\')\n                    os.remove(hashcat_link)\n                os.symlink(hashcat_bin, hashcat_link)\n                logging.info(f\'Created symlink: {hashcat_link} -> {hashcat_bin}\')\n            except Exception as e:\n                logging.error(f\'Failed to create symlink {hashcat_link}: {e}\')\n                return False\n            # Create hashcat.bin wrapper script with --backend-ignore-opencl\n            hashcat_bin_path = path / \'hashcat.bin\'\n            logging.info(f\'Creating hashcat.bin wrapper at: {hashcat_bin_path}\')\n            try:\n                if os.path.islink(hashcat_bin_path):\n                    logging.info(f\'Removing existing symlink: {hashcat_bin_path}\')\n                    os.unlink(hashcat_bin_path)\n                elif os.path.exists(hashcat_bin_path):\n                    logging.info(f\'Removing existing file: {hashcat_bin_path}\')\n                    os.remove(hashcat_bin_path)\n                with open(hashcat_bin_path, \'w\') as f:\n                    f.write(\'#!/run/current-system/sw/bin/bash\\n\')\n                    f.write(f\'exec \"{hashcat_bin}\" --backend-ignore-opencl \"$@\"\\n\')\n                os.chmod(hashcat_bin_path, 0o755)\n                logging.info(f\'Created hashcat.bin wrapper with --backend-ignore-opencl\')\n            except Exception as e:\n                logging.error(f\'Failed to create wrapper {hashcat_bin_path}: {e}\')\n                return False\n            return True\n        # End native hashcat patch - original method follows'
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
