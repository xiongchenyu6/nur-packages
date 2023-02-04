{ stdenv, makeWrapper, source, oraclejdk8, ... }:
stdenv.mkDerivation {
  name = "java-tron";
  doCheck = false;

  dontUnpack = true;

  buildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin/
    mkdir -p $out/lib/
    mkdir -p $out/etc/
    cp ${source.java-tron.src} $out/lib/FullNode.jar
    cp ${source.tron-deployment.src}/*.conf $out/etc/
    cp ${source.tron-deployment.src}/*.sh $out/bin/
    cp ${./plugin-kafka-1.0.0.zip} $out/lib/plugin-kafka.zip
    cp ${./plugin-mongodb-1.0.0.zip} $out/lib/plugin-mongodb.zip
    makeWrapper ${oraclejdk8}/bin/java $out/bin/java-tron --add-flags "-jar $out/lib/FullNode.jar "
  '';
}
