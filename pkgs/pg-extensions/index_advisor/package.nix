{
  lib,
  fetchFromGitHub,
  postgresql,
  postgresqlBuildExtension,
}:

# SQL-only extension: the upstream Makefile is a trivial PGXS wrapper that
# installs the .control and .sql files. No C compiler is invoked, but we still
# use postgresqlBuildExtension so the DESTDIR dance and install locations match
# every other PG extension on the system.
postgresqlBuildExtension {
  pname = "index_advisor";
  version = "0.2.0";

  src = fetchFromGitHub {
    owner = "supabase";
    repo = "index_advisor";
    rev = "ddb9b4ed17692ef8dbf049fad806426a851a3079";
    hash = "sha256-z7XiqfmUjBPNWNMowzUk/dfT5cLbQUQ3Uoir+xBgPjc=";
  };

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
