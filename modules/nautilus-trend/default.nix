{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.nautilus-trend;

  pythonEnv = pkgs.python313.withPackages (ps: [ cfg.package ps.psycopg2 ]);

  app = pkgs.runCommand "nautilus-trend-app" { } ''
    mkdir -p $out/app
    for f in live_trend.py signal_follower.py trade_ledger.py; do
      cp ${./.}/$f $out/app/$f
    done
  '';

  caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
in
{
  options.services.nautilus-trend = {
    enable = mkEnableOption ''
      Crypto trend node on NautilusTrader (Binance spot TESTNET only): executes the public house
      signals (quant.strategy_signals) and resumes holdings from quant.nautilus_trades'';

    package = mkOption {
      type = types.package;
      default = pkgs.nautilus-trader;
      defaultText = literalExpression "pkgs.nautilus-trader";
      description = "The nautilus-trader python package.";
    };

    assets = mkOption {
      type = types.listOf types.str;
      default = [ "BTC" "ETH" "SOL" "XRP" "DOGE" "ADA" "AVAX" "SUI" "NEAR" "UNI" "ZEC" "PEPE" "WLD" ];
      description = "House assets (= strategies/strategy_record.ASSETS); one SignalFollower each on <ASSET>USDT.";
    };

    notionalUsdt = mkOption {
      type = types.float;
      default = 500.0;
      description = "USDT per entry (capped by free USDT). 13 x 500 = 6.5k max deployed.";
    };

    pollSecs = mkOption {
      type = types.int;
      default = 60;
      description = "Seconds between checks of quant.strategy_signals.";
    };

    environmentFile = mkOption {
      type = types.path;
      description = ''
        EnvironmentFile with BINANCE_API_KEY + BINANCE_API_SECRET_FILE (Ed25519) + TIMESCALE_URL
        (required: signals + ledger). Reuse the nautilus-accumulator sops template — both run
        as the same `user`.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "nautilus";
      description = ''
        Service user. Defaults to `nautilus` (created by the nautilus-accumulator module);
        enable that module too, or create the user yourself.
      '';
    };

    group = mkOption {
      type = types.str;
      default = "nautilus";
      description = "Service group.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.nautilus-trend = {
      description = "Crypto trend node - public signal follower (NautilusTrader, Binance testnet)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        BINANCE_TESTNET = "1"; # live_trend.py refuses anything else (guardrail)
        NAUTILUS_ENV = "testnet";
        TREND_ASSETS = concatStringsSep "," cfg.assets;
        TREND_NOTIONAL_USDT = toString cfg.notionalUsdt;
        TREND_POLL_SECS = toString cfg.pollSecs;
        SSL_CERT_FILE = caBundle;
        NIX_SSL_CERT_FILE = caBundle;
        PYTHONUNBUFFERED = "1";
      };

      serviceConfig = {
        Type = "exec";
        ExecStart = "${pythonEnv}/bin/python ${app}/app/live_trend.py";
        EnvironmentFile = cfg.environmentFile;
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "30s";
        StateDirectory = "nautilus-trend";
        WorkingDirectory = "/var/lib/nautilus-trend";

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
