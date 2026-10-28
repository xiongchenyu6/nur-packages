{
  lib,
  pkgs,
  postgresql,
  postgresqlBuildExtension,
}:

let
  sources = pkgs.callPackage ../../../_sources/generated.nix { };
in
postgresqlBuildExtension {
  pname = "pg_hashids";
  version = "1.3-unstable-${sources.pg-hashids.date}";
  inherit (sources.pg-hashids) src;

  makeFlags = [ "USE_PGXS=1" ];

  enableUpdateScript = false;

  meta = {
    description = "Short unique id generators for PostgreSQL (implementation of hashids)";
    homepage = "https://github.com/iCyberon/pg_hashids";
    license = lib.licenses.mit;
    maintainers = [ ];
    platforms = postgresql.meta.platforms;
  };
}
