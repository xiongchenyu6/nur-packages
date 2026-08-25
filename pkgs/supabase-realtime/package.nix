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

  # Upstream requires Elixir ~> 1.19 while the default beam package set still
  # ships 1.18. mixRelease and fetchMixDeps no longer accept an `elixir`
  # argument, so build from a package set that already has the right version.
  beam = beamPackages.overrideScope (_: prev: { elixir = prev.elixir_1_19; });

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
beam.mixRelease {
  pname = "realtime";
  inherit version src;

  mixFodDeps = beam.fetchMixDeps {
    pname = "mix-deps-realtime";
    inherit src version;
    hash = "sha256-d1kXJcnjvq3Darz3R5MJk2uEOkIbnXKPmUY7Xw+tq2w=";
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
