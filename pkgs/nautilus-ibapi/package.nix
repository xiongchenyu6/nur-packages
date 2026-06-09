{
  lib,
  python313Packages,
  fetchurl,
}:

# nautilus-ibapi is NautilusTrader's fork of the official Interactive Brokers
# `ibapi` client (it installs the top-level `ibapi` module). It is the
# `nautilus-trader[ib]` extra's core dependency and is NOT in nixpkgs. Pure
# Python, so the universal py3 wheel installs as-is — no build step.
let
  py = python313Packages;
  version = "10.45.1";
in
py.buildPythonPackage {
  pname = "nautilus-ibapi";
  inherit version;
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/b6/81/46e4ba0b35bf3d5d5d32349ab4f54b1024e6a7e693a10cce3491c701a239/nautilus_ibapi-${version}-py3-none-any.whl";
    hash = "sha256-NOqN+PUg3Vh2Z6q3qZFmGNezchA8LCwbaOw7bhnGnFI=";
  };

  # The wheel ships the `ibapi` package (not `nautilus_ibapi`).
  pythonImportsCheck = [ "ibapi" ];

  meta = {
    description = "Interactive Brokers TWS API client, NautilusTrader fork (the nautilus-trader[ib] core dep)";
    homepage = "https://pypi.org/project/nautilus-ibapi/";
    license = lib.licenses.bsd0; # IB TWS API license (permissive)
    platforms = lib.platforms.all;
  };
}
