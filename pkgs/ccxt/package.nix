{
  lib,
  python313Packages,
  fetchurl,
}:

# ccxt — unified REST client for 100+ crypto exchanges. Not in nixpkgs. The quant
# executor (modules/quant-collectors, ccxt_executor.py) uses it to run the house
# strategies on Gate / HTX, which NautilusTrader has no adapters for. Pure Python:
# the py3 wheel installs as-is. Its wheel pins exact dependency versions; only the
# synchronous client is used, so the pins are not enforced against nixpkgs.
let
  py = python313Packages;
  version = "4.5.82";
in
py.buildPythonPackage {
  pname = "ccxt";
  inherit version;
  format = "wheel";

  src = fetchurl {
    url = "https://files.pythonhosted.org/packages/b8/87/f03c7407b84354ee2dfab6380b38c2b73fe8df0097f8d50d1ad0e0439d65/ccxt-${version}-py3-none-any.whl";
    hash = "sha256-RZJhYrWHgZlnbYGt50Ja7wlysayLCdXXCAioXSefaDg=";
  };

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
