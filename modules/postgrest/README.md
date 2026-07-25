# postgrest (home-manager only)

nixpkgs now ships `services.postgrest`, and having a second module declare the
same options makes any configuration importing both fail to evaluate with
`The option services.postgrest.enable ... is already declared`. So the NixOS
side of this module is gone — use the one in nixpkgs.

What nixpkgs does not have is a home-manager module, which is the whole reason
this one stays: hosts that cannot run NixOS still want PostgREST declaratively.
`home.nix` is exported as `homeModules.postgrest`.
