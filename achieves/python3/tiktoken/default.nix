{ python3, rustc, cargo, rustup, ... }:
let
  sources = import ../../../_sources/generated.nix {
    inherit (pkgs) fetchgit fetchFromGitHub fetchurl dockerTools;
  };
  inherit (python3.pkgs) buildPythonPackage;
  inherit (python3.pkgs) setuptools-rust;
in buildPythonPackage (sources.tiktoken // rec {
  propagatedBuildInputs = [ setuptools-rust rustup rustc cargo ];
  doCheck = false;
})
