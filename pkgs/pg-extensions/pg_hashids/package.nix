{
  lib,
  fetchFromGitHub,
  postgresql,
  postgresqlBuildExtension,
}:

postgresqlBuildExtension {
  pname = "pg_hashids";
  version = "1.3-unstable-2023-06-14";

  src = fetchFromGitHub {
    owner = "iCyberon";
    repo = "pg_hashids";
    rev = "8c404dd86408f3a987a3ff6825ac7e42bd618b98";
    hash = "sha256-mlS3YDE0VvF9zuLgz+EWSNLBZR1ptrU5A8ndY72194E=";
  };

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
