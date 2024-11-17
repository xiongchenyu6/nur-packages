{
  addOpenGLRunpath,
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
  ffmpeg-full,
  xdg-utils,
  unzip,
  onnxruntime,
  vips,
  icu,
  # for custom command line arguments, e.g. "--use-gl=desktop"
  commandLineArgs ? "",
}@args:

################################################################################
# Mostly based on dingtalk-bin package from AUR:
# https://aur.archlinux.org/packages/dingtalk-bin
################################################################################

let
  version = "0.0.1";

in
stdenv.mkDerivation rec {
  pname = "haystack-editor";

  inherit version;
  src = fetchurl {
    url = "https://d2dv27o1k99orf.cloudfront.net/Haystack+Editor+Linux.zip";
    sha256 = "sha256-YcWQYwWol4cDGgHd4bRYfC879I8BkRkvRyFcTWheOpY=";
  };

  nativeBuildInputs = [
    autoPatchelfHook
    unzip
    ffmpeg-full
  ];

  buildInputs = [
    gtk3
    onnxruntime
    vips
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
    ffmpeg-full
    xorg.libxkbfile
    onnxruntime
    vips
    icu
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

  unpackPhase = ''unzip ${src}'';
  autoPatchelfIgnoreMissingDeps = true;
  installPhase = ''
    mkdir -p $out/opt
    mv Haystack/* $out/opt
    install -D -m755 $out/opt/haystack-editor "$out/bin/haystack-editor" 
  '';

}
