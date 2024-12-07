{
  addDriverRunpath,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  autoPatchelfHook,
  cairo,
  cups,
  curl,
  dbus,
  dpkg,
  expat,
  fetchurl,
  fontconfig,
  freetype,
  gdk-pixbuf,
  glib,
  glibc,
  gnutls,
  gtk3,
  lib,
  libGL,
  xorg,
  libappindicator-gtk3,
  libcxx,
  libdbusmenu,
  libxkbcommon,
  libdrm,
  libgcrypt,
  libglvnd,
  libnotify,
  libpulseaudio,
  libuuid,
  makeShellWrapper,
  mesa,
  nspr,
  nss,
  pango,
  pciutils,
  pipewire,
  pixman,
  stdenv,
  systemd,
  wayland,
  wrapGAppsHook,
  xdg-utils,
  # for custom command line arguments, e.g. "--use-gl=desktop"
  commandLineArgs ? "",
}@args:

################################################################################
# Mostly based on dingtalk-bin package from AUR:
# https://aur.archlinux.org/packages/dingtalk-bin
################################################################################

let
  version = "7.28.10";

in
stdenv.mkDerivation rec {
  pname = "feishu-lark";
  packageHash = "1d51a0a0"; # A hash value used in the download url

  inherit version;
  src = fetchurl {
    url = "https://sf16-va.larksuitecdn.com/obj/lark-artifact-storage/${packageHash}/Lark-linux_x64-${version}.deb";

    sha256 = "sha256-011f1VZUruK+zBLTtGTl4QEDYgWJy2z2GSWwsWeq8Hs=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    makeShellWrapper
    dpkg
  ];

  buildInputs = [
    gtk3
    # for autopatchelf
    alsa-lib
    cups
    curl
    xorg.libXdamage
    xorg.libXtst
    libdrm
    libgcrypt
    libpulseaudio
    xorg.libxshmfence
    mesa
    nspr
    nss
  ];

  rpath = lib.makeLibraryPath [
    alsa-lib
    at-spi2-atk
    at-spi2-core
    atk
    cairo
    cups
    curl
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
    libcxx
    libdbusmenu
    libdrm
    libgcrypt
    libglvnd
    libnotify
    libpulseaudio
    libuuid
    xorg.libxcb
    libxkbcommon
    xorg.libxkbfile
    xorg.libxshmfence
    mesa
    nspr
    nss
    pango
    pciutils
    pipewire
    pixman
    stdenv.cc.cc
    systemd
    wayland
    xdg-utils
  ];

  dontUnpack = true;
  installPhase = ''
    # This deb file contains a setuid binary,
    # so 'dpkg -x' doesn't work here.
    dpkg --fsys-tarfile $src | tar --extract
    mkdir -p $out
    mv usr/share $out/
    mv opt/ $out/

    substituteInPlace $out/share/applications/bytedance-lark.desktop \
      --replace /usr/bin/bytedance-lark-stable $out/opt/bytedance/lark/bytedance-lark

    # Wrap feishu and vulcan
    # Feishu is the main executable, vulcan is the builtin browser
    for executable in $out/opt/bytedance/lark/{lark,vulcan/vulcan}; do
      wrapProgram $executable \
        --prefix XDG_DATA_DIRS    :  "$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH" \
        --prefix LD_LIBRARY_PATH  :  ${rpath}:$out/opt/bytedance/lark:${addDriverRunpath.driverLink}/share \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+ --enable-features=WaylandWindowDecorations}}" \
        ${
          lib.optionalString (commandLineArgs != "") "--add-flags ${lib.escapeShellArg commandLineArgs}"
        }
    done

    mkdir -p $out/share/icons/hicolor
    base="$out/opt/bytedance/lark"
    for size in 16 24 32 48 64 128 256; do
      mkdir -p $out/share/icons/hicolor/''${size}x''${size}/apps
      ln -s $base/product_logo_$size.png $out/share/icons/hicolor/''${size}x''${size}/apps/bytedance-lark.png
    done

    mkdir -p $out/bin
    ln -s $out/opt/bytedance/lark/bytedance-lark $out/bin/bytedance-lark

    # feishu comes with a bundled libcurl.so
    # and has many dependencies that are hard to satisfy
    # e.g. openldap version 2.4
    # so replace it with our own libcurl.so
    ln -sf ${curl}/lib/libcurl.so $out/opt/bytedance/lark/libcurl.so
  '';
}
