{
  lib,
  stdenv,
  fetchurl,
}:

let
  version = "v2026.03.09.0605-0e16f4b";

  sources = {
    x86_64-linux = {
      osArch = "linux-amd64";
      url = "https://github.com/xpzouying/xiaohongshu-mcp/releases/download/${version}/xiaohongshu-mcp-linux-amd64.tar.gz";
      hash = "sha256-T8CWYRffhG+GpUmJWn0X8nwQbT7dRwUCXXyUX4MfAwA=";
    };
    aarch64-linux = {
      osArch = "linux-arm64";
      url = "https://github.com/xpzouying/xiaohongshu-mcp/releases/download/${version}/xiaohongshu-mcp-linux-arm64.tar.gz";
      hash = "sha256-enM/uW4Fk5eqtTGH1MXmGk+HrIXbRWh3uDszNCVhY2s=";
    };
    x86_64-darwin = {
      osArch = "darwin-amd64";
      url = "https://github.com/xpzouying/xiaohongshu-mcp/releases/download/${version}/xiaohongshu-mcp-darwin-amd64.tar.gz";
      hash = "sha256-jec2Q/wV8E7xFRnGZJNNkgWnIZj4pTu3c7xZKXWKH58=";
    };
    aarch64-darwin = {
      osArch = "darwin-arm64";
      url = "https://github.com/xpzouying/xiaohongshu-mcp/releases/download/${version}/xiaohongshu-mcp-darwin-arm64.tar.gz";
      hash = "sha256-LR1LO8avMv2e1UbDkwnUJd0suaZBW+LmZSXNmjso/gU=";
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
