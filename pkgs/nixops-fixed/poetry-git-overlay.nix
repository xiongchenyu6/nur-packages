{ pkgs }:
_self: super: {

  nixops = super.nixops.overridePythonAttrs (_: {
    src = pkgs.fetchgit {
      url = "https://github.com/NixOS/nixops.git";
      rev = "683baa66c613216a662aad3fd58b0cdc5cd41adb";
      sha256 = "00yyzsybn1fjhkar64albxqp46d1v9c6lf1gd10lh9q72xq979sf";
    };
  });

  nixops-aws = super.nixops-aws.overridePythonAttrs (_: {
    src = pkgs.fetchgit {
      url = "https://github.com/xiongchenyu6/nixops-aws.git";
      rev = "efe1905509380e3ab5c3aba6d06dde693129a496";
      sha256 = "1dn5isq13bbmffm620gwbkalf151rrfm084wbr5apclggd7kyyiy";
    };
  });

  nixops-gcp = super.nixops-gcp.overridePythonAttrs (_: {
    src = pkgs.fetchgit {
      url = "https://github.com/xiongchenyu6/nixops-gce.git";
      rev = "9242e568d57a2929d29d3d4c9e474af454685691";
      sha256 = "0gbgwi5zwrxyl41ywbdnnxgvlcs3a0r1gl90jl9bdwmswn2jvww9";
    };
  });

  nixops-hetznercloud = super.nixops-hetznercloud.overridePythonAttrs (_: {
    src = pkgs.fetchgit {
      url = "https://github.com/xiongchenyu6/nixops-hetznercloud.git";
      rev = "48a8b908276543f1999c36df1982a30675963828";
      sha256 = "0ffd3m7z67i4fzm4d98zgl65d06j7qcqqzhr394gnkv7s95gnl0x";
    };
  });

  nixos-modules-contrib = super.nixos-modules-contrib.overridePythonAttrs (_: {
    src = pkgs.fetchgit {
      url = "https://github.com/nix-community/nixos-modules-contrib.git";
      rev = "81a1c2ef424dcf596a97b2e46a58ca73a1dd1ff8";
      sha256 = "0f6ra5r8i1jz8ymw6l3j68b676a1lv0466lv0xa6mi80k6v9457x";
    };
  });

}
