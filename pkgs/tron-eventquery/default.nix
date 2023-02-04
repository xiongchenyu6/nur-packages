{ stdenv, makeWrapper, openjdk8, ... }:
stdenv.mkDerivation {
  name = "tron-eventquery";
  doCheck = false;

  dontUnpack = true;

  buildInputs = [ makeWrapper ];

  installPhase = ''
    mkdir -p $out/bin/
    makeWrapper ${openjdk8}/bin/java $out/bin/tron-eventquery --add-flags "-jar ${
      ./troneventquery-1.0.0-SNAPSHOT.jar
    } "
  '';
}

