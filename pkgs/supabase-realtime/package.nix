{
  pkgs,
  lib,
  beamPackages,
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
  src = sources.supabase-realtime.src;
  version = lib.removePrefix "v" sources.supabase-realtime.version;
in
beamPackages.mixRelease {
  pname = "realtime";
  inherit version src;

  mixFodDeps = beamPackages.fetchMixDeps {
    pname = "mix-deps-realtime";
    inherit src version;
    hash = "sha256-IsWk9MM3BgX1Cme9SqOHPM4MmOkKQnH3IANpnM3McfE=";
  };

  meta = with lib; {
    description = "Scalable WebSockets engine over PostgreSQL logical replication";
    homepage = "https://github.com/supabase/realtime";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
