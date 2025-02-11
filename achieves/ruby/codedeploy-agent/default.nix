{ ruby, makeWrapper, bundlerEnv, stdenv, ...
}:
let
  sources = import ../../../_sources/generated.nix {
    inherit (pkgs) fetchgit fetchFromGitHub fetchurl dockerTools;
  };
  # the magic which will include gemset.nix
  aws-source = sources.aws-codedeploy-agent;

  gems = bundlerEnv (aws-source.src // {
    name = "aws-codedeploymet-agent-env";
    inherit ruby;
    gemdir = aws-source.src;
    ignoreCollisions = true;
    copyGemFiles = true;
  });
in stdenv.mkDerivation {
  name = "aws-codedeployment-agent";
  propagatedBuildInputs = [ gems gems.wrappedRuby makeWrapper ];
  inherit (aws-source) src;
  installPhase = ''
    mkdir -p $out/bin
    cp -r * $out/
    makeWrapper ${gems.wrappedRuby}/bin/ruby $out/bin/codedeploy-agent --add-flags "$out/lib/codedeploy-agent.rb"
  '';
}
# stdenv.mkDerivation (aws-sourcee // {
#   name = "aws-codedeploymet-agent";
#   buildInputs = [ gems ruby ];
#   installPhase = ''
#     rake clean && rake
#     mkdir -p $out/{bin}
#     cp -r * $out/bin
#   '';
# })

