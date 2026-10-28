{
  lib,
  pkgs,
  postgresql,
  postgresqlBuildExtension,
}:

# SQL-only extension: the upstream Makefile is a trivial PGXS wrapper that
# installs the .control and .sql files. No C compiler is invoked, but we still
# use postgresqlBuildExtension so the DESTDIR dance and install locations match
# every other PG extension on the system.
let
  sources = pkgs.callPackage ../../../_sources/generated.nix { };
in
postgresqlBuildExtension {
  pname = "index_advisor";
  version = lib.removePrefix "v" sources.index-advisor.version;
  inherit (sources.index-advisor) src;

  makeFlags = [ "USE_PGXS=1" ];

  enableUpdateScript = false;

  meta = {
    description = "Query index advisor for PostgreSQL (suggests indexes using hypopg)";
    homepage = "https://github.com/supabase/index_advisor";
    license = lib.licenses.postgresql;
    maintainers = [ ];
    platforms = postgresql.meta.platforms;
  };
}
