{
  lib,
  pkgs,
  stdenv,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  wrapGAppsHook3,
  glib-networking,
  webkitgtk_4_1,
  gtk3,
  libayatana-appindicator,
  openssl,
}:
let
  sources = import ../../_sources/generated.nix {
    inherit (pkgs)
      fetchurl
      dockerTools
      fetchgit
      fetchFromGitHub
      ;
  };

  platformSources = {
    "x86_64-linux" = sources.cc-switch-linux-x86_64;
    "aarch64-linux" = sources.cc-switch-linux-arm64;
    "x86_64-darwin" = sources.cc-switch-darwin-x86_64;
    "aarch64-darwin" = sources.cc-switch-darwin-arm64;
  };

  platformSource =
    platformSources.${stdenv.hostPlatform.system}
      or (throw "Unsupported system: ${stdenv.hostPlatform.system}");

  isLinux = stdenv.hostPlatform.isLinux;
in
stdenv.mkDerivation {
  pname = "cc-switch";
  inherit (platformSource) version;

  inherit (platformSource) src;

  nativeBuildInputs =
    lib.optionals isLinux [
      dpkg
      autoPatchelfHook
      wrapGAppsHook3
    ]
    ++ lib.optionals (!isLinux) [ makeWrapper ];

  # Matches the .deb's own Depends: libwebkit2gtk-4.1-0, libgtk-3-0,
  # libayatana-appindicator3-1.
  buildInputs = lib.optionals isLinux [
    webkitgtk_4_1
    gtk3
    libayatana-appindicator
    openssl
  ];

  unpackPhase =
    if isLinux then
      ''
        runHook preUnpack
        dpkg-deb -x $src .
        runHook postUnpack
      ''
    else
      ''
        runHook preUnpack
        mkdir -p tmp
        tar xzf $src -C tmp
        runHook postUnpack
      '';

  installPhase =
    if isLinux then
      ''
        runHook preInstall

        mkdir -p $out
        cp -r usr/bin usr/share $out/

        # Upstream ships the entry as "CC Switch.desktop" — a space in the
        # desktop file id — and its Exec line has no %u, so xdg-open launches
        # the app without the ccswitch:// URL and the deep link is dropped.
        mv "$out/share/applications/CC Switch.desktop" \
          $out/share/applications/cc-switch.desktop
        substituteInPlace $out/share/applications/cc-switch.desktop \
          --replace-fail 'Exec=cc-switch' "Exec=$out/bin/cc-switch %u" \
          --replace-fail 'Categories=' 'Categories=Development;Utility;'

        runHook postInstall
      ''
    else
      ''
        runHook preInstall

        mkdir -p $out/bin

        app_path=$(find tmp -name "*.app" -type d | head -1)
        if [ -z "$app_path" ]; then
          echo "Error: No .app bundle found in extracted archive"
          exit 1
        fi

        makeWrapper "$app_path/Contents/MacOS/cc-switch" $out/bin/cc-switch

        mkdir -p $out/share/cc-switch
        cp -r "$app_path" $out/share/cc-switch/

        runHook postInstall
      '';

  # Two runtime lookups autoPatchelfHook cannot see:
  #   - libappindicator-sys dlopen()s libayatana-appindicator3.so by soname, so
  #     it is absent from DT_NEEDED and the binary panics on startup without it
  #   - GIO loads its TLS backend as a module, so every HTTPS request the app
  #     makes fails unless glib-networking is on the module path
  preFixup = lib.optionalString isLinux ''
    gappsWrapperArgs+=(
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath [ libayatana-appindicator ]}"
      --prefix GIO_EXTRA_MODULES : "${glib-networking}/lib/gio/modules"
    )
  '';

  meta = with lib; {
    description = "Cross-platform desktop app for managing AI coding tools (Claude Code, Codex, OpenCode, etc.)";
    homepage = "https://github.com/farion1231/cc-switch";
    license = licenses.gpl3;
    maintainers = [ ];
    platforms = builtins.attrNames platformSources;
    mainProgram = "cc-switch";
  };
}
