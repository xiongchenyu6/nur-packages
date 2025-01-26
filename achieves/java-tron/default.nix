{ stdenv, makeWrapper, source, openjdk8, ... }:
stdenv.mkDerivation {
  name = "java-tron";
  doCheck = false;

  dontUnpack = true;

  buildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin/
    mkdir -p $out/lib/
    mkdir -p $out/etc/
    cp ${source.java-tron-full-node.src} $out/lib/FullNode.jar
    cp ${source.java-tron-solidity-node.src} $out/lib/SolidityNode.jar
    cp ${source.tron-deployment.src}/*.conf $out/etc/
    cp ${source.tron-deployment.src}/*.sh $out/bin/
    cp ${./plugin-kafka-1.0.0.zip} $out/lib/plugin-kafka.zip
    cp ${./plugin-mongodb-1.0.0.zip} $out/lib/plugin-mongodb.zip
    makeWrapper ${openjdk8}/bin/java $out/bin/java-tron-full-node --add-flags "-jar $out/lib/FullNode.jar "
    makeWrapper ${openjdk8}/bin/java $out/bin/java-tron-solidity-node --add-flags "-jar $out/lib/SolidityNode.jar "
  '';
}
