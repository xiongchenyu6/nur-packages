{
  pkgs,
  stdenv,
  lib,
  nixosTests,
  nix-update-script,
  buildGoModule,
  fetchFromGitHub,
  installShellFiles,
  pkg-config,
  gtk3,
  libayatana-appindicator,
  xorg,
  ui ? false,
  netbird-ui,
}:
let
  modules =
    if ui then
      {
        "client/ui" = "netbird-ui";
      }
    else
      {
        client = "netbird";
        management = "netbird-mgmt";
        signal = "netbird-signal";
      };
  sources = import ../../_sources/generated.nix {
    inherit (pkgs)
      fetchgit
      fetchFromGitHub
      fetchurl
      dockerTools
      ;
  };
in
buildGoModule (
  sources.netbird
  // (
    let
      netbird = (lib.importJSON ../../_sources/generated.json).netbird;
      version = netbird.version;
    in
    {
      pname = "netbird";
      inherit version;

      vendorHash = "sha256-30KSccdeQ+DrYjotCR0w0LvY1jCBBJIAy5rKQtSsD9Q=";

      nativeBuildInputs = [ installShellFiles ] ++ lib.optional ui pkg-config;

      buildInputs =
        lib.optionals (stdenv.hostPlatform.isLinux && ui) [
          gtk3
          libayatana-appindicator
          xorg.libX11
          xorg.libXcursor
          xorg.libXxf86vm
        ]
        ++ lib.optionals (stdenv.hostPlatform.isDarwin && ui) [
        ];

      subPackages = lib.attrNames modules;

      ldflags = [
        "-s"
        "-w"
        "-X github.com/netbirdio/netbird/version.version=${version}"
        "-X main.builtBy=nix"
      ];

      # needs network access
      doCheck = false;

      postPatch = ''
        # make it compatible with systemd's RuntimeDirectory
        substituteInPlace client/cmd/root.go \
          --replace-fail 'unix:///var/run/netbird.sock' 'unix:///var/run/netbird/sock'
        substituteInPlace client/ui/client_ui.go \
          --replace-fail 'unix:///var/run/netbird.sock' 'unix:///var/run/netbird/sock'
      '';

      postInstall =
        lib.concatStringsSep "\n" (
          lib.mapAttrsToList (
            module: binary:
            ''
              mv $out/bin/${lib.last (lib.splitString "/" module)} $out/bin/${binary}
            ''
            + lib.optionalString (!ui) ''
              installShellCompletion --cmd ${binary} \
                --bash <($out/bin/${binary} completion bash) \
                --fish <($out/bin/${binary} completion fish) \
                --zsh <($out/bin/${binary} completion zsh)
            ''
          ) modules
        )
        + lib.optionalString (stdenv.hostPlatform.isLinux && ui) ''
          mkdir -p $out/share/pixmaps
          cp $src/client/ui/netbird-systemtray-connected.png $out/share/pixmaps/netbird.png

          mkdir -p $out/share/applications
          cp $src/client/ui/netbird.desktop $out/share/applications/netbird.desktop

          substituteInPlace $out/share/applications/netbird.desktop \
            --replace-fail "Exec=/usr/bin/netbird-ui" "Exec=$out/bin/netbird-ui"
        '';
    }
  )
)
