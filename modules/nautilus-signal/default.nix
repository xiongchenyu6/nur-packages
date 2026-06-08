{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.nautilus-signal;

  # nautilus-trader + requests/certifi (for the Telegram sink). No psycopg2 — this node
  # writes no DB; it only reads public market data and sends Telegram messages.
  pythonEnv = pkgs.python313.withPackages (ps: [
    cfg.package
    ps.requests
    ps.certifi
  ]);

  app = pkgs.runCommand "nautilus-signal-app" { } ''
    mkdir -p $out/app
    for f in run_signal_alerter.py signal_alerter.py signal_detect.py telegram_notifier.py; do
      cp ${./.}/$f $out/app/$f
    done
  '';

  caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
in
{
  options.services.nautilus-signal = {
    enable = mkEnableOption "Crypto signal layer (spike + accumulation-dip Telegram alerts) on NautilusTrader";

    package = mkOption {
      type = types.package;
      default = pkgs.nautilus-trader;
      defaultText = literalExpression "pkgs.nautilus-trader";
      description = "The nautilus-trader python package (from the xiongchenyu6 NUR overlay).";
    };

    instruments = mkOption {
      type = types.listOf types.str;
      default = [ "BTCUSDT.BINANCE" "ETHUSDT.BINANCE" "SOLUSDT.BINANCE" ];
      description = "Instrument ids to monitor for spike/dip signals.";
    };

    barSpec = mkOption {
      type = types.str;
      default = "1-MINUTE-LAST-EXTERNAL";
      description = "Bar type spec appended to each instrument. Minute bars for timely signals.";
    };

    environmentFile = mkOption {
      type = types.path;
      example = "/run/secrets/nautilus-signal.env";
      description = ''
        EnvironmentFile providing TELEGRAM_BOT_TOKEN and TELEGRAM_CHAT_ID (the alert sink).
        Use sops-nix templates so secrets are materialized at runtime, never in the Nix store.
        BINANCE_API_KEY/SECRET are optional — only needed if Binance rate-limits anonymous data.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "nautilus";
      description = "User to run the service as (shared with the other nautilus services).";
    };

    group = mkOption {
      type = types.str;
      default = "nautilus";
      description = "Primary group for the service user.";
    };
  };

  config = mkIf cfg.enable {
    # The nautilus user is shared across the nautilus-* services. Declare it with
    # mkDefault so co-enabling nautilus-accumulator (which sets a literal description)
    # doesn't conflict, while this module still works standalone.
    users.users = mkIf (cfg.user == "nautilus") {
      nautilus = {
        isSystemUser = true;
        group = cfg.group;
        description = mkDefault "nautilus services runner";
      };
    };
    users.groups = mkIf (cfg.group == "nautilus") { nautilus = { }; };

    systemd.services.nautilus-signal = {
      description = "Crypto signal layer — spike/dip Telegram alerts (NautilusTrader, Binance mainnet data-only)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        SIGNAL_INSTRUMENTS = concatStringsSep " " cfg.instruments;
        SIGNAL_BAR = cfg.barSpec;
        SSL_CERT_FILE = caBundle;
        NIX_SSL_CERT_FILE = caBundle;
        PYTHONUNBUFFERED = "1";
      };

      serviceConfig = {
        Type = "exec";
        ExecStart = "${pythonEnv}/bin/python ${app}/app/run_signal_alerter.py";
        EnvironmentFile = cfg.environmentFile;
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "30s";
        StateDirectory = "nautilus-signal";
        WorkingDirectory = "/var/lib/nautilus-signal";

        # Hardening (same profile as nautilus-accumulator; data-only so no extra access needed)
        CapabilityBoundingSet = "";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectClock = true;
        ProtectControlGroups = true;
        ProtectHome = true;
        ProtectHostname = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        RestrictAddressFamilies = "AF_INET AF_INET6 AF_UNIX";
        RestrictNamespaces = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = "@system-service";
      };
    };
  };
}
