# nvkvm-pv: paravirtual NVIDIA GPU sharing for KVM guests.
#
# nixpkgs' KVM-only QEMU plus what upstream's scripts/build_qemu.sh does to a
# QEMU v11.1.1 checkout: the twelve patches in patches/, the device sources
# copied into hw/misc/, and the isolate stub built first and embedded
# (NVKVM_STUB_EMBEDDED) so nothing has to live in /usr/lib/nvkvm at runtime.
#
# $out/share/nvkvm-pv holds the matching guest side (kernel module sources,
# guest scripts, tests/validate.sh) for exporting to a guest read-only. The
# guest module must come from the same revision as this QEMU.
{
  lib,
  applyPatches,
  fetchFromGitHub,
  qemu_kvm,
  xxd,
}:
let
  version = "0.2.5-unstable-2026-09-28";
  src = applyPatches {
    name = "nvkvm-pv-${version}-src";
    src = fetchFromGitHub {
      owner = "reindertpelsma";
      repo = "nvkvm-pv";
      rev = "39972874d22f5ba19e39827488b089e80a0c17f4";
      hash = "sha256-M4hHu60LqvzcAT9xIUPpx2YXQLED7jGz6mwGskNhup8=";
    };
    # Guest-module fix, written for upstream (commit message carries the
    # analysis and the control-allowlist audit); not yet submitted.
    # cuMemAllocManaged failed on every GPU but the host's first.
    patches = [ ./0001-guest-managed-memory-owner-gpu.patch ];
  };
in
qemu_kvm.overrideAttrs (old: {
  pname = "nvkvm-pv";
  version = "${version}-qemu-${old.version}";
  # nixpkgs derives the tarball URL from finalAttrs.version.
  inherit (qemu_kvm) src;

  nativeBuildInputs = old.nativeBuildInputs ++ [ xxd ];

  # Mirrors scripts/build_qemu.sh steps 2-4.
  postPatch = (old.postPatch or "") + ''
    for p in ${src}/patches/*.patch; do
      echo "applying nvkvm patch $(basename "$p")"
      patch -p1 --no-backup-if-mismatch < "$p"
    done

    cp -r ${src} "$NIX_BUILD_TOP/nvkvm-src"
    chmod -R u+w "$NIX_BUILD_TOP/nvkvm-src"
    make -C "$NIX_BUILD_TOP/nvkvm-src/src/stub"

    nv="$NIX_BUILD_TOP/nvkvm-src/src"
    cp "$nv"/qemu/*.c "$nv"/qemu/*.h hw/misc/
    mkdir -p hw/misc/nvkvm_inc
    cp "$nv"/abi/*.h "$nv"/common/*.h hw/misc/nvkvm_inc/
    cp "$nv"/qemu/nvkvm_linux_types.h hw/misc/nvkvm_inc/linux_types_compat.h
    cp "$nv"/stub/nvkvm_stub_bin.h hw/misc/
    sed -i -E 's#"\.\./\.\./src/(common|abi)/([A-Za-z0-9_]+\.h)"#"nvkvm_inc/\2"#g' \
      hw/misc/*.c hw/misc/*.h
    sed -i 's|#include <linux/types.h>|#include "linux_types_compat.h"|g' \
      hw/misc/nvkvm_inc/*.h
  '';

  # Without it nvkvm_isolate.c silently builds with no stub and fails at
  # runtime with "open ctl/gpu FAILED".
  env = (old.env or { }) // {
    NIX_CFLAGS_COMPILE = toString [
      (old.env.NIX_CFLAGS_COMPILE or "")
      "-DNVKVM_STUB_EMBEDDED"
    ];
  };

  postInstall = (old.postInstall or "") + ''
    share=$out/share/nvkvm-pv
    mkdir -p $share/src
    cp -r ${src}/src/guest ${src}/src/common ${src}/src/abi $share/src/
    cp -r ${src}/scripts ${src}/tests ${src}/data $share/
    cp ${src}/LICENSE ${src}/README.md $share/
  '';

  # nixpkgs' QEMU test suite is long and unrelated to the added device.
  doCheck = false;

  passthru = (old.passthru or { }) // {
    nvkvmVersion = version;
    nvkvmSrc = src;
  };

  meta = old.meta // {
    description = "QEMU with the nvkvm-pv virtio-nvgpu paravirtual NVIDIA GPU device";
    homepage = "https://github.com/reindertpelsma/nvkvm-pv";
    license = with lib.licenses; [
      gpl2Plus
      asl20
    ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "qemu-system-x86_64";
  };
})
