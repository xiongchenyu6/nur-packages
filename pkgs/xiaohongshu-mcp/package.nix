{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "v2026.03.04.0231-db81fd8";

  sources = {
    x86_64-linux = {
      osArch = "linux-amd64";
      url = "https://github.com/xpzouying/xiaohongshu-mcp/releases/download/${version}/xiaohongshu-mcp-linux-amd64.tar.gz";
      hash = "sha256-Im3h0923bdLtNQI3sw9gp3k81hTacRpL8itRhc7qavk=";
    };
    aarch64-linux = {
      osArch = "linux-arm64";
      url = "https://github.com/xpzouying/xiaohongshu-mcp/releases/download/${version}/xiaohongshu-mcp-linux-arm64.tar.gz";
      hash = "sha256-TULMiB7+y4A7FEApD3b5Ng0H5sBABd5yixX+YqqIlmU=";
    };
    x86_64-darwin = {
      osArch = "darwin-amd64";
      url = "https://github.com/xpzouying/xiaohongshu-mcp/releases/download/${version}/xiaohongshu-mcp-darwin-amd64.tar.gz";
      hash = "sha256-7flQ6aKP7B6AlJ3ayhvrj7wBmfaK90/dr60Ckmjvy34=";
    };
    aarch64-darwin = {
      osArch = "darwin-arm64";
      url = "https://github.com/xpzouying/xiaohongshu-mcp/releases/download/${version}/xiaohongshu-mcp-darwin-arm64.tar.gz";
      hash = "sha256-wo+CabtKEje47UfVDoYr7PaHmo0UwHljlxcis8NAZx0=";
    };
  };

  # Get current platform's source
  current = sources.${stdenv.hostPlatform.system};
in

stdenv.mkDerivation rec {
  pname = "xiaohongshu-mcp";
  inherit version;

  src = fetchurl {
    url = current.url;
    sha256 = current.hash;
  };

  dontBuild = true;
  dontConfigure = true;

  unpackPhase = ''
    tar xzf $src
  '';

  installPhase = ''
    mkdir -p $out/bin
    install -m755 ./xiaohongshu-mcp-${current.osArch} $out/bin/xiaohongshu-mcp
    install -m755 ./xiaohongshu-login-${current.osArch} $out/bin/xiaohongshu-login
  '';

  meta = with lib; {
    description = "MCP server for xiaohongshu.com (Little Red Book)";
    homepage = "https://github.com/xpzouying/xiaohongshu-mcp";
    license = licenses.mit;
    platforms = builtins.attrNames sources;
    maintainers = [ ];
  };
}
