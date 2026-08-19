# home-manager versions of the service modules, for hosts that cannot run
# NixOS. Only services whose module has been split into common/nixos/home are
# listed; the rest remain NixOS-only.
#
# Every unit here runs in the user manager, which means:
#   - `loginctl enable-linger <user>` is required, or the units stop at logout
#   - ports below 1024 cannot be bound (no CAP_NET_BIND_SERVICE)
#   - state lives under $XDG_STATE_HOME rather than /var/lib
#   - PostgreSQL and Redis are not managed — home-manager has no module for
#     either, so point the relevant options at instances run some other way
{
  casdoor = import ./casdoor/home.nix;
  cc-switch = import ./cc-switch/home.nix;
  gotrue-supabase = import ./gotrue-supabase/home.nix;
  postgrest = import ./postgrest/home.nix;
  sub2api = import ./sub2api/home.nix;
  supabase-realtime = import ./supabase-realtime/home.nix;
}
