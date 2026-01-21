{
  stdenv,
  lib,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  makeWrapper,
  addDriverRunpath,
  # Runtime dependencies
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  cairo,
  cups,
  dbus,
  expat,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  glibc,
  gnutls,
  gtk3,
  libGL,
  xorg,
  libappindicator-gtk3,
  libdrm,
  libgbm,
  libgcrypt,
  libglvnd,
  libnotify,
  libpulseaudio,
  libsecret,
  libxtst,
  libxkbcommon,
  mesa,
  nspr,
  nss,
  pango,
  pciutils,
  pipewire,
  pixman,
  systemd,
  util-linux,
  wayland,
  wrapGAppsHook3,
  xdg-utils,
}:

################################################################################
# RoxyBrowser - Premier Antidetect Browser
# Package definition for Nix/NixOS
################################################################################

let
  pname = "roxybrowser";
  version = "3.6.8";
  arch = "amd64";

  src = fetchurl {
    url = "https://dl.roxybrowser.com/app-download/Linux-64-latest";
    hash = "sha256-bxas6m8AdpEVl15/LzGifypB9s0EpMBZaDh8jTBWKxM=";
    name = "${pname}_${version}_${arch}.deb";
  };
in
stdenv.mkDerivation rec {
  inherit pname version src;

  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
    dpkg
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk3
    # Required runtime dependencies
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    glibc
    gnutls
    libGL
    libappindicator-gtk3
    libdrm
    libgbm
    libgcrypt
    libnotify
    libpulseaudio
    libsecret
    libxtst
    libxkbcommon
    mesa
    nspr
    nss
    pango
    pciutils
    pipewire
    pixman
    systemd
    util-linux
    wayland
    xdg-utils
    xorg.libX11
    xorg.libXScrnSaver
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXtst
    xorg.libxcb
    xorg.libxkbfile
    xorg.libxshmfence
  ];

  # Build the runtime library path
  rpath = lib.makeLibraryPath [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    dbus
    expat
    fontconfig
    freetype
    gdk-pixbuf
    glib
    glibc
    gnutls
    libGL
    xorg.libX11
    xorg.libXScrnSaver
    xorg.libXcomposite
    xorg.libXcursor
    xorg.libXdamage
    xorg.libXext
    xorg.libXfixes
    xorg.libXi
    xorg.libXrandr
    xorg.libXrender
    xorg.libXtst
    libappindicator-gtk3
    libdrm
    libgbm
    libgcrypt
    libglvnd
    libnotify
    libpulseaudio
    libsecret
    libxtst
    libxkbcommon
    mesa
    nspr
    nss
    pango
    pciutils
    pipewire
    pixman
    stdenv.cc.cc
    systemd
    util-linux
    wayland
    xdg-utils
    xorg.libxcb
    xorg.libxkbfile
    xorg.libxshmfence
  ];

  # Disable wrapGAppsHook from wrapping, we'll do it manually
  dontWrapGApps = true;

  dontUnpack = true;

  installPhase = ''
            runHook preInstall

            # Extract the .deb file
            dpkg-deb -x $src extraction
            mkdir -p $out

            # Copy extracted contents to output
            cp -r extraction/usr/* $out/
            mkdir -p $out/opt
            cp -r extraction/opt/* $out/opt/

            # Fix permissions
            chmod -R u+w $out

            # The binary is at opt/RoxyBrowser/roxybrowser
            ROXY_EXE="$out/opt/RoxyBrowser/roxybrowser"

            if [ ! -f "$ROXY_EXE" ]; then
              echo "ERROR: Could not find roxybrowser executable at $ROXY_EXE"
              exit 1
            fi

        # Create a shell wrapper script that EXPORTS LD_LIBRARY_PATH
        # This ensures child processes (Chrome cores downloaded at runtime) inherit the library path
        # We also set NIX_LD_LIBRARY_PATH for nix-ld compatibility
        mkdir -p $out/bin
        cat > $out/bin/roxybrowser << 'WRAPPER_EOF'
    #!/usr/bin/env bash
    LIBS="RPATH_PLACEHOLDER"
    export LD_LIBRARY_PATH="''${LD_LIBRARY_PATH:+''$LD_LIBRARY_PATH:}''$LIBS"
    export NIX_LD_LIBRARY_PATH="''${NIX_LD_LIBRARY_PATH:+''$NIX_LD_LIBRARY_PATH:}''$LIBS"
    export XDG_DATA_DIRS="''${XDG_DATA_DIRS:+''$XDG_DATA_DIRS:}XDG_PLACEHOLDER"
    exec "EXE_PLACEHOLDER" "''$@"
    WRAPPER_EOF

            substituteInPlace $out/bin/roxybrowser \
              --replace-fail "RPATH_PLACEHOLDER" "${rpath}:$out/opt/RoxyBrowser:${addDriverRunpath.driverLink}/lib" \
              --replace-fail "XDG_PLACEHOLDER" "$XDG_DATA_DIRS:$GSETTINGS_SCHEMAS_PATH" \
              --replace-fail "EXE_PLACEHOLDER" "$ROXY_EXE"
            chmod +x $out/bin/roxybrowser

            # Create desktop entry if it exists
            if [ -d $out/share/applications ]; then
              for desktop in $out/share/applications/*.desktop; do
                if [ -f "$desktop" ]; then
                  substituteInPlace "$desktop" \
                    --replace-quiet /usr/bin $out/bin \
                    --replace-quiet /opt/RoxyBrowser $out/opt/RoxyBrowser
                fi
              done
            fi

            runHook postInstall
  '';

  meta = with lib; {
    description = "RoxyBrowser - Premier Antidetect Browser for managing multiple online identities";
    longDescription = ''
      RoxyBrowser is an antidetect browser designed for professionals who manage
      multiple online identities securely. It provides advanced fingerprint technology,
      workspace collaboration, and integrated proxy management for various use cases
      including e-commerce, affiliate marketing, crypto trading, SEO, and automation.
    '';
    homepage = "https://roxybrowser.com/";
    license = licenses.mit;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
