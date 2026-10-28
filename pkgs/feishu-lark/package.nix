{
  addDriverRunpath,
  alsa-lib,
  at-spi2-atk,
  at-spi2-core,
  atk,
  autoPatchelfHook,
  cairo,
  cups,
  dbus,
  dpkg,
  expat,
  pkgs,
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
  sources = import ../../_sources/generated.nix {
    inherit (pkgs)
      fetchgit
      fetchFromGitHub
      fetchurl
      dockerTools
      ;
  };
  platformSources = {
    x86_64-linux = sources.feishu-lark-linux-x64;
    aarch64-linux = sources.feishu-lark-linux-arm64;
  };
  source = platformSources.${stdenv.hostPlatform.system};
  # The release API supplies a CDN URL with an opaque path, so nvfetcher tracks
  # that URL. Expose the application version rather than the URL as our version.
  version = builtins.head (
    builtins.match "Lark-linux_[^-]+-(.*)\\.deb" (builtins.baseNameOf source.version)
  );
in
stdenv.mkDerivation rec {
  pname = "feishu-lark";
  inherit version;
  inherit (source) src;
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
  # Preserve vendor resource payloads in the prebuilt binaries.
  dontStrip = true;
  installPhase = ''
    # This deb file contains a setuid binary,
    # so 'dpkg -x' doesn't work here.
    dpkg --fsys-tarfile $src | tar --extract
    mkdir -p $out
    mv usr/share $out/
    mv opt/ $out/

    substituteInPlace $out/share/applications/bytedance-lark.desktop \
      --replace /usr/bin/bytedance-lark-stable $out/opt/bytedance/lark/bytedance-lark

    # Keep the ELF filename intact: the client resolves resources from its own
    # executable path. Wrap the vendor launcher instead.
    for executable in $out/opt/bytedance/lark/bytedance-lark; do
      wrapProgram $executable \
        --prefix XDG_DATA_DIRS    :  "$XDG_ICON_DIRS:$GSETTINGS_SCHEMAS_PATH" \
        --prefix LD_LIBRARY_PATH  :  ${rpath}:$out/opt/bytedance/lark:${addDriverRunpath.driverLink}/lib \
        --add-flags "\''${NIXOS_OZONE_WL:+\''${WAYLAND_DISPLAY:+ --enable-features=WaylandWindowDecorations}}" \
        ${lib.optionalString (
          commandLineArgs != ""
        ) "--add-flags ${lib.escapeShellArg commandLineArgs}"}
    done

    mkdir -p $out/share/icons/hicolor
    base="$out/opt/bytedance/lark"
    for size in 16 24 32 48 64 128 256; do
      mkdir -p $out/share/icons/hicolor/''${size}x''${size}/apps
      ln -s $base/product_logo_$size.png $out/share/icons/hicolor/''${size}x''${size}/apps/bytedance-lark.png
    done

    mkdir -p $out/bin
    ln -s $out/opt/bytedance/lark/bytedance-lark $out/bin/bytedance-lark
  '';

  meta = with lib; {
    description = "Lark desktop client";
    homepage = "https://www.larksuite.com/";
    license = licenses.unfree;
    platforms = builtins.attrNames platformSources;
    maintainers = [ ];
  };
}
