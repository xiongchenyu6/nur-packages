{ bundlerApp }:

bundlerApp {
  pname = "pg-ldap-sync";
  gemdir = ./.;
  exes = [ "pg_ldap_sync" ];
}
