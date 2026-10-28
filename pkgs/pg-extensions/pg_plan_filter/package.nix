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
  pname = "pg_plan_filter";
  version = lib.removePrefix "v" sources.pg-plan-filter.version;
  inherit (sources.pg-plan-filter) src;

  makeFlags = [ "USE_PGXS=1" ];

  enableUpdateScript = false;

  meta = {
    description = "PostgreSQL module to filter statements by plan cost before executing them";
    homepage = "https://github.com/pgexperts/pg_plan_filter";
    license = lib.licenses.postgresql;
    maintainers = [ ];
    platforms = postgresql.meta.platforms;
  };
}
