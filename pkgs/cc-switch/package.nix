{
  lib,
  pkgs,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  appimage-run,
}:
let
  sources = import ../../_sources/generated.nix {
    inherit (pkgs) fetchurl dockerTools fetchgit fetchFromGitHub;
  };

  platformSources = {
    "x86_64-linux" = sources.cc-switch-linux-x86_64;
    "aarch64-linux" = sources.cc-switch-linux-arm64;
    "x86_64-darwin" = sources.cc-switch-darwin-x86_64;
    "aarch64-darwin" = sources.cc-switch-darwin-arm64;
  };

  platformSource = platformSources.${stdenv.hostPlatform.system}
    or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  isLinux = stdenv.hostPlatform.isLinux;
  isDarwin = stdenv.hostPlatform.isDarwin;

  linuxDeps = [
    pkgs.glib
    pkgs.gtk3
    pkgs.libnotify
    pkgs.nss
    pkgs.libsecret
    pkgs.at-spi2-core
    pkgs.libdrm
    pkgs.mesa
    pkgs.libgbm
    pkgs.libxkbfile
    pkgs.libxcb
    pkgs.xcbutilwm
    pkgs.xcbutilimage
    pkgs.xcbutilkeysyms
    pkgs.xcbutilrenderutil
    pkgs.fontconfig
    pkgs.freetype
    pkgs.harfbuzz
    pkgs.fribidi
    pkgs.expat
    pkgs.libgpg-error
    pkgs.e2fsprogs
    pkgs.gmp
    pkgs.libx11
    pkgs.libxext
    pkgs.libxfixes
    pkgs.libxi
    pkgs.libxrandr
    pkgs.libxrender
    pkgs.libxtst
    pkgs.libXScrnSaver
    pkgs.libxcomposite
    pkgs.libxdamage
    pkgs.libxcursor
    pkgs.libxinerama
    pkgs.libxshmfence
    pkgs.libxxf86vm
    pkgs.alsa-lib
    pkgs.pulseaudio
    pkgs.dbus
    pkgs.atk
    pkgs.cairo
    pkgs.pango
    pkgs.gdk-pixbuf
  ];

  linuxLibPath = lib.makeLibraryPath (lib.optionals isLinux linuxDeps);
in
stdenv.mkDerivation {
  pname = "cc-switch";
  inherit (platformSource) version;

  src = platformSource.src;

  nativeBuildInputs = [
    appimage-run
    autoPatchelfHook
    makeWrapper
  ];

  buildInputs = lib.optionals isLinux linuxDeps;

  unpackPhase = if isLinux then ''
    # AppImage doesn't need unpacking, we'll extract it in installPhase
    mkdir -p $TMPDIR/appimage
  '' else ''
    # macOS tar.gz - extract
    runHook preUnpack
    mkdir -p tmp
    tar xzf $src -C tmp
    runHook postUnpack
  '';

  installPhase = if isLinux then ''
    runHook preInstall

    # Extract AppImage
    cd $TMPDIR/appimage
    appimage-run -x . $src

    # Install the extracted AppImage contents (extracted directly to current dir)
    mkdir -p $out
    cp -r ./* $out/

    # Fix up the binary - autoPatchelfHook runs automatically via nativeBuildInputs
    patchShebangs $out

    # Create wrapper script for the AppRun
    makeWrapper $out/AppRun $out/bin/cc-switch \
      --add-flags "--no-sandbox" \
      --set LD_LIBRARY_PATH "${linuxLibPath}" \
      --set APPIMAGE_EXIT_AFTER_INSTALL "1"

    runHook postInstall
  '' else ''
    runHook preInstall

    # macOS: install the extracted app bundle
    mkdir -p $out/bin
    
    # Find the .app bundle in the extracted contents
    app_path=$(find tmp -name "*.app" -type d | head -1)
    if [ -z "$app_path" ]; then
      echo "Error: No .app bundle found in extracted archive"
      exit 1
    fi

    # Create a wrapper that launches the app
    makeWrapper "$app_path/Contents/MacOS/cc-switch" $out/bin/cc-switch \
      --add-flags "--no-sandbox"

    # Also copy the app bundle to share for proper integration
    mkdir -p $out/share/cc-switch
    cp -r "$app_path" $out/share/cc-switch/

    runHook postInstall
  '';

  dontFixup = isLinux; # autoPatchelfHook handles this

  meta = with lib; {
    description = "Cross-platform desktop app for managing AI coding tools (Claude Code, Codex, OpenCode, etc.)";
    homepage = "https://github.com/farion1231/cc-switch";
    license = licenses.gpl3;
    maintainers = [ ];
    platforms = builtins.attrNames platformSources;
    mainProgram = "cc-switch";
  };
}