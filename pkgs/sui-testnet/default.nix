{
  lib,
  stdenv,
  source,
  autoPatchelfHook,
}:

stdenv.mkDerivation (
  source.sui
  // (
    let
      sui = (lib.importJSON ../../_sources/generated.json).sui;
      version = sui.version;
    in
    rec {
      pname = "sui-testnet";
      inherit version;

      nativeBuildInputs = [
        autoPatchelfHook
      ];

      buildInputs = [
        stdenv.cc.cc.lib # Adds libstdc++.so.6 and libgcc_s.so.1
      ];

      # Unpack to a temporary directory
      unpackPhase = ''
        mkdir -p tmp
        tar xzf $src -C tmp
      '';

      installPhase = ''
        mkdir -p $out/bin
        for binary in \
          move-analyzer \
          sui \
          sui-bridge \
          sui-bridge-cli \
          sui-data-ingestion \
          sui-debug \
          sui-faucet \
          sui-graphql-rpc \
          sui-node \
          sui-test-validator \
          sui-tool
        do
          install -m755 tmp/$binary $out/bin/$binary
        done
      '';

      # Skip unnecessary phases
      dontConfigure = true;
      dontBuild = true;
      dontFixup = false; # Needed for autoPatchelfHook
      dontPatch = true;

      meta = with lib; {
        description = "Sui testnet binaries";
        homepage = "https://sui.io";
        license = licenses.asl20;
        platforms = [ "x86_64-linux" ];
        maintainers = [ "freeman" ];
      };
    }
  )
)
