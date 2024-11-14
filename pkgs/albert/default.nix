{
  lib,
  stdenv,
  fetchFromGitHub,
  qt6,
  cmake,
  libqalculate,
  muparser,
  libarchive,
  python311Packages,
  nix-update-script,
  pkg-config,
  source,
}:

stdenv.mkDerivation (
  finalAttrs:
  (
    source.albert
    // {
      pname = "albert";
      version = "0.26.7";

      nativeBuildInputs = [
        cmake
        pkg-config
        qt6.wrapQtAppsHook
      ];

      buildInputs =
        [
          libqalculate
          libarchive
          muparser
          qt6.qtbase
          qt6.qtscxml
          qt6.qtsvg
          qt6.qtdeclarative
          qt6.qtwayland
          qt6.qt5compat
          qt6.qttools
        ]
        ++ (with python311Packages; [
          python
          pybind11
        ]);

      postPatch = ''
        find -type f -name CMakeLists.txt -exec sed -i {} -e '/INSTALL_RPATH/d' \;

        substituteInPlace src/app/qtpluginprovider.cpp \
          --replace-fail "QStringList install_paths;" "QStringList install_paths;${"\n"}install_paths << QFileInfo(\"$out/lib\").canonicalFilePath();"
      '';

      postFixup = ''
        for i in $out/{bin/.albert-wrapped,lib/albert/plugins/*.so}; do
          patchelf $i --add-rpath $out/lib/albert
        done
      '';

      passthru = {
        updateScript = nix-update-script { };
      };

    }
  )
)
