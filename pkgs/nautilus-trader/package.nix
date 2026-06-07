{
  lib,
  stdenv,
  fetchurl,
  python313,
  python313Packages,
  autoPatchelfHook,
}:

let
  py = python313Packages;
  version = "1.227.0";

  # Platform-specific manylinux wheels (Rust-native; no sdist build).
  wheels = {
    "x86_64-linux" = {
      url = "https://files.pythonhosted.org/packages/8c/12/2b6487c5ce2c84eaf6b25cf7386583d77c20ebdf0155627f112530c33529/nautilus_trader-${version}-cp313-cp313-manylinux_2_35_x86_64.whl";
      hash = "sha256:4d1f16442744696919e6351ce6a720a47b944d392568d9f528694f35ed63e159";
    };
    "aarch64-linux" = {
      url = "https://files.pythonhosted.org/packages/1e/e0/90f0d000a14b5e8b6e9906d33ac6d925a150d163c32376589918d35f5f4e/nautilus_trader-${version}-cp313-cp313-manylinux_2_35_aarch64.whl";
      hash = "sha256:c3e83dcb8bdb27b5b7f33da21c5ab82784ff6ff95abf01b03a1cd1dbb3703d22";
    };
  };
  wheel = wheels.${stdenv.hostPlatform.system} or (throw "nautilus-trader: unsupported system ${stdenv.hostPlatform.system}");
in
py.buildPythonPackage {
  pname = "nautilus-trader";
  inherit version;
  format = "wheel";

  src = fetchurl wheel;

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  # The compiled Rust extension links against the C++ runtime.
  buildInputs = [
    stdenv.cc.cc.lib
  ];

  propagatedBuildInputs = with py; [
    numpy
    pandas
    pyarrow
    msgspec
    click
    fsspec
    portion
    protobuf
    python-dateutil
    pytz
    tqdm
    tzdata
    uvloop
  ];

  # The wheel pins exact dep versions that differ slightly from nixpkgs; Python
  # doesn't enforce these at runtime, so skip the strict runtime-deps check.
  dontCheckRuntimeDeps = true;

  pythonImportsCheck = [
    "nautilus_trader"
    "nautilus_trader.adapters.binance"
  ];

  meta = {
    description = "High-performance algorithmic trading platform (Rust-native), packaged from the official wheel";
    homepage = "https://nautilustrader.io";
    license = lib.licenses.lgpl3Only;
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
  };
}
