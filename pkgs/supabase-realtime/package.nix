{
  pkgs,
  lib,
  beamPackages,
  fetchurl,
  stdenv,
}:
let
  sources = import ../../_sources/generated.nix {
    inherit (pkgs)
      fetchgit
      fetchFromGitHub
      fetchurl
      dockerTools
      ;
  };
  src = sources.supabase-realtime.src;
  version = lib.removePrefix "v" sources.supabase-realtime.version;

  # Upstream requires Elixir ~> 1.19; the default beamPackages still ships 1.18.
  elixir = pkgs.elixir_1_19;

  # The lumis dependency loads a rustler_precompiled NIF, which tries to
  # download its precompiled artifact at compile time. Prefetch the tarballs
  # and seed rustler_precompiled's cache instead; integrity is still verified
  # against the checksum file shipped inside the lumis hex package.
  # Bump these (version + hashes) when mix.lock moves to a new lumis.
  lumisVersion = "0.7.0";
  lumisNifTargets =
    {
      "x86_64-linux" = [
        {
          target = "x86_64-unknown-linux-gnu";
          hash = "sha256-zh7GDZkhVyZMXa8vSzrsIVsbkJrMl7V/fk9uuTX8vno=";
        }
        {
          target = "x86_64-unknown-linux-gnu--legacy_cpu";
          hash = "sha256-cejdwX0/ITJas50zRrnasruLYmzOHALLqZ/g+ZJQTSA=";
        }
      ];
      "aarch64-linux" = [
        {
          target = "aarch64-unknown-linux-gnu";
          hash = "sha256-jbnvElRGhGBEwfrrZePEySNpo3ZkDbNpjuMl9bIAX8I=";
        }
      ];
    }
    .${stdenv.hostPlatform.system};
  lumisNifs = map (
    { target, hash }:
    rec {
      name = "liblumis_nif-v${lumisVersion}-nif-2.15-${target}.so.tar.gz";
      tarball = fetchurl {
        inherit hash;
        url = "https://github.com/leandrocp/lumis/releases/download/hex-lumis%2Fv${lumisVersion}/${name}";
      };
    }
  ) lumisNifTargets;
in
beamPackages.mixRelease {
  pname = "realtime";
  inherit version src elixir;

  mixFodDeps = beamPackages.fetchMixDeps {
    pname = "mix-deps-realtime";
    inherit src version elixir;
    hash = "sha256-dpTes5pNpBdUlLPjMNOY74p1xY8VfQAn4Ur8nzZb850=";
  };

  preConfigure = ''
    export XDG_CACHE_HOME="$TMPDIR/xdg-cache"
    mkdir -p "$XDG_CACHE_HOME/rustler_precompiled/precompiled_nifs"
    ${lib.concatMapStringsSep "\n" (nif: ''
      cp ${nif.tarball} "$XDG_CACHE_HOME/rustler_precompiled/precompiled_nifs/${nif.name}"
    '') lumisNifs}
  '';

  meta = with lib; {
    description = "Scalable WebSockets engine over PostgreSQL logical replication";
    homepage = "https://github.com/supabase/realtime";
    license = licenses.asl20;
    maintainers = [ ];
    platforms = platforms.linux;
  };
}
