{ stdenv, bundix, bundlerEnv, ruby, sourcee, symlinkJoin, ... }:
let
  # the magic which will include gemset.nix
  aws-sourcee = sourcee.aws-codedeploy-agent;

  gen-bundix = stdenv.mkDerivation (aws-sourcee // {
    name = "aws-codedeploy-agent-bundix";
    nativeBuildInputs = [ bundix ruby ];
    buildPhase = ''
      bundle lock
      bundix'';
    installPhase = ''
      cp gemset.nix $out/gemset.nix
    '';
    outputHashAlgo = "sha256";
    outputHashMode = "recursive";
    outputHash = "sha256-uA1jWloiWADMbt2x2FlVYHMsv4ftQDyIzjU2JUCF4IA=";
  });
  gems = bundlerEnv ({
    name = "aws-codedeploymet-agent-env";
    inherit ruby;
    gemdir = "${gen-bundix}/share";
  });
in bundlerEnv (aws-sourcee.src // {
  name = "aws-codedeploymet-agent-env";
  inherit ruby;
  gemfile = "${aws-sourcee.src}/Gemfile";
  lockfile = "${aws-sourcee.src}/Gemfile.lock";
  gemset = "${gen-bundix}/gemset.nix";
  ignoreCollisions = true;
  copyGemFiles = true;
  extraConfigPaths = [ ./codedeploy_agent.gemspec ];
})

# stdenv.mkDerivation (aws-sourcee // {
#   name = "aws-codedeploymet-agent";
#   buildInputs = [ gems ruby ];
#   installPhase = ''
#     rake clean && rake
#     mkdir -p $out/{bin}
#     cp -r * $out/bin
#   '';
# })
