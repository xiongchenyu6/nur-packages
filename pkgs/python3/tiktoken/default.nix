{ python3, source, rustc, cargo, rustup, ... }:
let
  inherit (python3.pkgs) buildPythonPackage;
  inherit (python3.pkgs) setuptools-rust;
in buildPythonPackage (source.tiktoken // rec {
  propagatedBuildInputs = [ setuptools-rust rustup rustc cargo ];
  doCheck = false;
})
