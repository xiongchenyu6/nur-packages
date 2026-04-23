{
  lib,
  fetchFromGitHub,
  postgresql,
  postgresqlBuildExtension,
}:

postgresqlBuildExtension {
  pname = "pg_plan_filter";
  version = "unstable-2021-09-23";

  src = fetchFromGitHub {
    owner = "pgexperts";
    repo = "pg_plan_filter";
    rev = "5081a7b5cb890876e67d8e7486b6a64c38c9a492";
    hash = "sha256-YNeIfmccT/DtOrwDmpYFCuV2/P6k3Zj23VWBDkOh6sw=";
  };

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
