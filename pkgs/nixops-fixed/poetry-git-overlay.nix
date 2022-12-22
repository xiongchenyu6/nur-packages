{ pkgs }:
self: super: {

  nixops = super.nixops.overridePythonAttrs (
    _: {
      src = pkgs.fetchgit {
        url = "https://github.com/NixOS/nixops.git";
        rev = "683baa66c613216a662aad3fd58b0cdc5cd41adb";
        sha256 = "00yyzsybn1fjhkar64albxqp46d1v9c6lf1gd10lh9q72xq979sf";
      };
    }
  );

  nixops-aws = super.nixops-aws.overridePythonAttrs (
    _: {
      src = pkgs.fetchgit {
        url = "https://github.com/mvnetbiz/nixops-aws.git";
        rev = "17d3bdac06a70a2ee7d76892d37bf07b0efbb30b";
        sha256 = "156dhbb0ivw605aaylib8pwz4pb11vgpjgkhp67iwcgqvq6if4cr";
      };
    }
  );

  nixos-modules-contrib = super.nixos-modules-contrib.overridePythonAttrs (
    _: {
      src = pkgs.fetchgit {
        url = "https://github.com/nix-community/nixos-modules-contrib.git";
        rev = "81a1c2ef424dcf596a97b2e46a58ca73a1dd1ff8";
        sha256 = "0f6ra5r8i1jz8ymw6l3j68b676a1lv0466lv0xa6mi80k6v9457x";
      };
    }
  );

}
