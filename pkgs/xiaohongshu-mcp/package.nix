{
  pkgs,
  buildGoModule,
  lib,
  ...
}:
let
  sources = import ../../_sources/generated.nix {
    inherit (pkgs)
      fetchgit
      fetchFromGitHub
      fetchurl
      dockerTools
      ;
  };
in
buildGoModule (
  sources.xiaohongshu-mcp
  // {
    subPackages = [
      "."
      "cmd/login"
    ];
    vendorHash = "sha256-WeBjIgsAiUMcbZfdIJ+RhBn1IIq2N+ooMAWFJhN5RQc=";
    doCheck = false;
    postInstall = ''
      mv $out/bin/login $out/bin/xiaohongshu-login
    '';
    meta = with lib; {
      description = "MCP server for xiaohongshu.com (Little Red Book)";
      homepage = "https://github.com/xpzouying/xiaohongshu-mcp";
      license = licenses.mit;
      maintainers = [ ];
    };
  }
)
