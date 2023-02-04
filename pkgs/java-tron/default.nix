{ stdenv, makeWrapper, source, openjdk8, ... }:
stdenv.mkDerivation {
  name = "java-tron";
  doCheck = false;

  dontUnpack = true;

  buildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin/
    mkdir -p $out/lib/
    mkdir -p $out/conf/
    cp ${source.java-tron.src} $out/lib/FullNode.jar
    cp ${source.tron-deployment.src}/*.conf $out/conf/
    cp ${source.tron-deployment.src}/*.sh $out/bin/
    makeWrapper ${openjdk8}/bin/java $out/bin/java-tron --add-flags "-jar $out/lib/FullNode.jar "
  '';
}
