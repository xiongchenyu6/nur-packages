{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.freqtrade-ohlc-sync;

  pythonEnv = cfg.package.python.withPackages (ps: [
    ps.ccxt
    ps.psycopg2
  ]);

  syncScript = pkgs.runCommand "sync-ohlc-py" { } ''
    install -Dm755 ${./sync_ohlc.py} $out/bin/sync-ohlc
    sed -i '1c#!${pythonEnv}/bin/python3' $out/bin/sync-ohlc
  '';

  argv = concatStringsSep " " (
    [
      "--pairs"
    ]
    ++ map escapeShellArg cfg.pairs
    ++ [ "--timeframes" ]
    ++ map escapeShellArg cfg.timeframes
    ++ [
      "--backfill-days"
      (toString cfg.backfillDays)
    ]
    ++ optionals (cfg.refreshViews != null) (
      [ "--refresh-views" ] ++ map escapeShellArg cfg.refreshViews
    )
  );
in
{
  options.services.freqtrade-ohlc-sync = {
    enable = mkEnableOption "Periodic sync of recent OHLC candles to TimescaleDB";

    package = mkOption {
      type = types.attrsOf types.package;
      default = {
        python = pkgs.python3;
      };
      description = ''
        Attribute set with a `python` interpreter to use for the sync. Override
        if you need a specific Python version (e.g. `pkgs.python311`).
      '';
    };

    pairs = mkOption {
      type = types.listOf types.str;
      default = [
        "BTC/USDT"
        "ETH/USDT"
        "BNB/USDT"
        "SOL/USDT"
      ];
      description = "CCXT pair symbols to keep current.";
    };

    timeframes = mkOption {
      type = types.listOf types.str;
      default = [ "1m" ];
      description = ''
        CCXT timeframes to fetch. Usually just `1m` since downstream
        TimescaleDB continuous aggregates derive 15m/1h/1d from it.
      '';
    };

    exchange = mkOption {
      type = types.str;
      default = "binance";
      description = "CCXT exchange id to fetch from.";
    };

    schema = mkOption {
      type = types.str;
      default = "quant";
      description = "PostgreSQL schema containing the `ohlc` hypertable.";
    };

    table = mkOption {
      type = types.str;
      default = "ohlc";
      description = "Hypertable name (must have unique constraint on pair, tf, ts).";
    };

    backfillDays = mkOption {
      type = types.int;
      default = 3;
      description = ''
        On the first run (empty hypertable), fetch this many days of
        historical 1m candles. Subsequent runs are incremental from
        max(ts) so this only matters once.
      '';
    };

    refreshViews = mkOption {
      type = types.nullOr (types.listOf types.str);
      default = [
        "ohlc_15m"
        "ohlc_1h"
        "ohlc_1d"
      ];
      description = ''
        TimescaleDB continuous aggregate views to refresh after each sync.
        Set to `null` or `[]` to skip the refresh step (useful when the
        DB doesn't host the aggregates).
      '';
    };

    onCalendar = mkOption {
      type = types.str;
      default = "*:0/15";
      description = ''
        systemd OnCalendar expression. Defaults to every 15 minutes;
        Binance public REST happily serves this cadence per host.
      '';
    };

    randomizedDelaySec = mkOption {
      type = types.int;
      default = 60;
      description = "RandomizedDelaySec to spread load across hosts.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/ohlc-sync.env";
      description = ''
        Path to an EnvironmentFile providing `TIMESCALE_URL=postgres://…`
        (and optionally `TIMESCALE_SCHEMA`/`TIMESCALE_TABLE` to override
        the module options). Use sops-nix's templates so the file is
        materialized at runtime, never in the Nix store.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "freqtrade-ohlc";
      description = "User to run the sync as.";
    };

    group = mkOption {
      type = types.str;
      default = "freqtrade-ohlc";
      description = "Primary group for the sync user.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.environmentFile != null;
        message = ''
          services.freqtrade-ohlc-sync.environmentFile must point to a file
          providing TIMESCALE_URL. Use sops.templates."ohlc-sync-env".path or
          equivalent secret-management.
        '';
      }
    ];

    users.users = mkIf (cfg.user == "freqtrade-ohlc") {
      freqtrade-ohlc = {
        isSystemUser = true;
        group = cfg.group;
        description = "freqtrade-ohlc-sync runner";
      };
    };

    users.groups = mkIf (cfg.group == "freqtrade-ohlc") {
      freqtrade-ohlc = { };
    };

    systemd.services.freqtrade-ohlc-sync = {
      description = "Sync recent OHLC candles to TimescaleDB";
      after = [
        "network-online.target"
        "postgresql.service"
      ];
      wants = [ "network-online.target" ];

      environment = {
        TIMESCALE_SCHEMA = cfg.schema;
        TIMESCALE_TABLE = cfg.table;
        OHLC_EXCHANGE = cfg.exchange;
      };

      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${syncScript}/bin/sync-ohlc ${argv}";
        EnvironmentFile = cfg.environmentFile;
        User = cfg.user;
        Group = cfg.group;
        TimeoutStartSec = "10min";

        # Hardening — script only needs network + outbound DB connection.
        CapabilityBoundingSet = "";
        DeviceAllow = "";
        LockPersonality = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        PrivateUsers = true;
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

    systemd.timers.freqtrade-ohlc-sync = {
      description = "Schedule for freqtrade-ohlc-sync";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.onCalendar;
        Persistent = true;
        RandomizedDelaySec = cfg.randomizedDelaySec;
        AccuracySec = "30s";
      };
    };
  };
}
