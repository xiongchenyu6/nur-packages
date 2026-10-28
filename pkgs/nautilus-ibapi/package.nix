{
  lib,
  python313Packages,
  pkgs,
}:

# nautilus-ibapi is NautilusTrader's fork of the official Interactive Brokers
# `ibapi` client (it installs the top-level `ibapi` module). It is the
# `nautilus-trader[ib]` extra's core dependency and is NOT in nixpkgs. Pure
# Python, so the universal py3 wheel installs as-is — no build step.
let
  py = python313Packages;
  sources = pkgs.callPackage ../../_sources/generated.nix { };
  inherit (sources.nautilus-ibapi) version src;
in
py.buildPythonPackage {
  pname = "nautilus-ibapi";
  inherit version src;
  format = "wheel";

  # The wheel ships the `ibapi` package (not `nautilus_ibapi`).
  pythonImportsCheck = [ "ibapi" ];

  meta = {
    description = "Interactive Brokers TWS API client, NautilusTrader fork (the nautilus-trader[ib] core dep)";
    homepage = "https://pypi.org/project/nautilus-ibapi/";
    license = lib.licenses.bsd0; # IB TWS API license (permissive)
    platforms = lib.platforms.all;
  };
}
