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
    for f in live_trend.py donchian.py trade_ledger.py honest_trend_equity.py regime_gate.py kelly_sizer.py crypto_data.py fetch_fng.py; do
      cp ${./.}/$f $out/app/$f
    done
  '';

  caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  fngCsv = "/var/lib/nautilus-trend/fng_history.csv";
in
{
  options.services.nautilus-trend = {
    enable = mkEnableOption "Crypto trend follower (HonestTrend) on NautilusTrader (Binance)";

    package = mkOption {
      type = types.package;
      default = pkgs.nautilus-trader;
      defaultText = literalExpression "pkgs.nautilus-trader";
      description = "The nautilus-trader python package.";
    };

    instruments = mkOption {
      type = types.listOf types.str;
      default = [ "ETHUSDT.BINANCE" "BTCUSDT.BINANCE" "SOLUSDT.BINANCE" ];
      description = "Instrument ids for the Donchian breakout (one strategy instance each).";
    };

    barSpec = mkOption {
      type = types.str;
      default = "1-HOUR-LAST-EXTERNAL";
      description = "Bar type spec. Donchian winner uses 1h.";
    };

    riskFrac = mkOption {
      type = types.float;
      default = 0.0667;
      description = "Fraction of equity per instrument (3 × 6.67% ≈ 20% total).";
    };

    entryLb = mkOption {
      type = types.int;
      default = 168;
      description = "Donchian entry lookback (bars).";
    };

    exitLb = mkOption {
      type = types.int;
      default = 72;
      description = "Donchian exit lookback (bars).";
    };

    testnet = mkOption {
      type = types.bool;
      default = true;
      description = "Trade against Binance testnet (no real money). Mainnet = false.";
    };

    environmentFile = mkOption {
      type = types.path;
      description = ''
        EnvironmentFile with BINANCE_API_KEY + BINANCE_API_SECRET_FILE (Ed25519). Reuse
        the nautilus-accumulator sops template — both run as the same `user`.
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
      description = "Crypto trend follower (NautilusTrader, Binance ${optionalString cfg.testnet "testnet"})";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        BINANCE_TESTNET = if cfg.testnet then "1" else "0";
        NAUTILUS_ENV = if cfg.testnet then "testnet" else "live";
        BINANCE_BAR = cfg.barSpec;
        TREND_INSTRUMENTS = concatStringsSep "," cfg.instruments;
        TREND_RISK_FRAC = toString cfg.riskFrac;
        TREND_ENTRY_LB = toString cfg.entryLb;
        TREND_EXIT_LB = toString cfg.exitLb;
        FNG_CSV = fngCsv;
        SSL_CERT_FILE = caBundle;
        NIX_SSL_CERT_FILE = caBundle;
        PYTHONUNBUFFERED = "1";
      };

      serviceConfig = {
        Type = "exec";
        ExecStartPre = "${pythonEnv}/bin/python ${app}/app/fetch_fng.py ${fngCsv}";
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
