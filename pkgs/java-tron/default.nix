{ stdenv, makeWrapper, source, openjdk8, ... }:
stdenv.mkDerivation {
  name = "java-tron";
  doCheck = false;

  dontUnpack = true;

  buildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin/
    mkdir -p $out/lib/
    cp ${source.java-tron.src} $out/lib/FullNode.jar
    makeWrapper ${openjdk8}/bin/java $out/bin/java-tron --add-flags "-jar $out/lib/FullNode.jar "
  '';
}
