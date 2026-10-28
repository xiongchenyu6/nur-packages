{
  lib,
  python313Packages,
  pkgs,
}:

# ccxt — unified REST client for 100+ crypto exchanges. Not in nixpkgs. The quant
# executor (modules/quant-collectors, ccxt_executor.py) uses it to run the house
# strategies on Gate / HTX, which NautilusTrader has no adapters for. Pure Python:
# the py3 wheel installs as-is. Its wheel pins exact dependency versions; only the
# synchronous client is used, so the pins are not enforced against nixpkgs.
let
  py = python313Packages;
  sources = pkgs.callPackage ../../_sources/generated.nix { };
  inherit (sources.ccxt) version src;
in
py.buildPythonPackage {
  pname = "ccxt";
  inherit version src;
  format = "wheel";

  dependencies = with py; [
    aiohttp
    certifi
    cryptography
    requests
    typing-extensions
    yarl
  ];
  dontCheckRuntimeDeps = true;

  pythonImportsCheck = [ "ccxt" ];

  meta = {
    description = "Cryptocurrency exchange trading library (unified API for 100+ exchanges)";
    homepage = "https://github.com/ccxt/ccxt";
    license = lib.licenses.mit;
    platforms = lib.platforms.all;
  };
}
