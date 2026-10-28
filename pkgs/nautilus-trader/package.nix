{
  lib,
  stdenv,
  pkgs,
  python313,
  python313Packages,
  autoPatchelfHook,
}:

let
  py = python313Packages;
  sources = pkgs.callPackage ../../_sources/generated.nix { };
  platformSource =
    {
      x86_64-linux = sources.nautilus-trader-linux-x86_64;
      aarch64-linux = sources.nautilus-trader-linux-arm64;
    }
    .${stdenv.hostPlatform.system}
      or (throw "nautilus-trader: unsupported system ${stdenv.hostPlatform.system}");

in
py.buildPythonPackage {
  pname = "nautilus-trader";
  inherit (platformSource) version src;
  format = "wheel";

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
