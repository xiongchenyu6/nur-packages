{
  lib,
  buildPgrxExtension,
  cargo-pgrx_0_16_1,
  pkgs,
  postgresql,
}:

let
  sources = pkgs.callPackage ../../../_sources/generated.nix { };
in
buildPgrxExtension {
  pname = "pg_ecdsa_verify";
  version = "1.2.4-unstable-${sources.pg-ecdsa-verify.date}";
  inherit (sources.pg-ecdsa-verify) src;

  # Upstream does not commit a Cargo.lock; this one resolves pgrx to 0.16.1,
  # which must match the pinned cargo-pgrx below.
  cargoLock.lockFile = ./Cargo.lock;
  postPatch = ''
    cp ${./Cargo.lock} Cargo.lock
  '';

  inherit postgresql;
  cargo-pgrx = cargo-pgrx_0_16_1;

  # pgrx tests install the extension into PostgreSQL's read-only store path, as
  # for every pgrx extension in nixpkgs.
  doCheck = false;

  meta = {
    description = "ECDSA (secp256r1/secp256k1, SHA-256) signature verification for PostgreSQL";
    homepage = "https://github.com/joelonsql/pg_ecdsa_verify";
    license = lib.licenses.mit;
    maintainers = [ ];
    platforms = postgresql.meta.platforms;
  };
}
