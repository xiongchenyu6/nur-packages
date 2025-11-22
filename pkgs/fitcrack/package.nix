{ lib
, stdenv
, fetchFromGitHub
, php82
, python3
, makeWrapper
}:

stdenv.mkDerivation rec {
  pname = "fitcrack";
  version = "2.4.0";

  src = fetchFromGitHub {
    owner = "nesfit";
    repo = "fitcrack";
    rev = "v${version}";
    sha256 = "0wynb37isv17sb4hxfc5iw5jzr3q28l8600f3s3aby7h22hcz102";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [ makeWrapper ];

  buildInputs = [
    php82
    python3
  ];

  installPhase = ''
    runHook preInstall

    # Create output directory structure
    mkdir -p $out/share/fitcrack
    mkdir -p $out/bin

    # Copy server files
    cp -r server $out/share/fitcrack/
    cp -r webadmin $out/share/fitcrack/
    cp -r runner $out/share/fitcrack/
    cp -r installer $out/share/fitcrack/
    cp env.example $out/share/fitcrack/

    # Create wrapper script
    makeWrapper ${php82}/bin/php $out/bin/fitcrack-server \
      --add-flags "-S 0.0.0.0:8080 -t $out/share/fitcrack/webadmin/public"

    runHook postInstall
  '';

  meta = with lib; {
    description = "BOINC-based distributed password cracking system";
    homepage = "https://fitcrack.fit.vutbr.cz";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}