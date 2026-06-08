{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.nautilus-accumulator;

  # Python env with the NUR nautilus-trader package (pandas etc. come transitively).
  pythonEnv = pkgs.python313.withPackages (ps: [ cfg.package ps.psycopg2 ]);

  app = pkgs.runCommand "nautilus-accumulator-app" { } ''
    mkdir -p $out/app
    cp ${./live_accumulation.py} $out/app/live_accumulation.py
    cp ${./accumulator.py}       $out/app/accumulator.py
    cp ${./crypto_data.py}       $out/app/crypto_data.py
    cp ${./trade_ledger.py}      $out/app/trade_ledger.py
    cp ${./fetch_fng.py}         $out/app/fetch_fng.py
  '';

  caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
  fngCsv = "/var/lib/nautilus-accumulator/fng_history.csv";
in
{
  options.services.nautilus-accumulator = {
    enable = mkEnableOption "Fear-driven crypto accumulation on NautilusTrader (Binance)";

    package = mkOption {
      type = types.package;
      default = pkgs.nautilus-trader;
      defaultText = literalExpression "pkgs.nautilus-trader";
      description = "The nautilus-trader python package (from the xiongchenyu6 NUR overlay).";
    };

    instrument = mkOption {
      type = types.str;
      default = "BTCUSDT.BINANCE";
      description = "Nautilus instrument id to accumulate.";
    };

    barSpec = mkOption {
      type = types.str;
      default = "1-DAY-LAST-EXTERNAL";
      description = ''
        Bar type spec appended to the instrument. Daily for real accumulation cadence;
        use 1-MINUTE-LAST-EXTERNAL for a fast smoke test.
      '';
    };

    testnet = mkOption {
      type = types.bool;
      default = true;
      description = ''
        Trade against the Binance testnet (no real money). MUST stay true until a long
        clean soak has proven reconnect/timeout/reconciliation. Mainnet = false.
      '';
    };

    baseBuyUsd = mkOption {
      type = types.float;
      default = 100.0;
      description = "Base buy size (USD) per scheduled buy, before fear/dip boosts.";
    };

    intervalBars = mkOption {
      type = types.int;
      default = 1;
      description = "Buy every N bars (e.g. 7 = weekly on daily bars).";
    };

    mode = mkOption {
      type = types.enum [ "smart" "naive" ];
      default = "smart";
      description = "smart = fear+dip boosted DCA; naive = fixed-interval DCA.";
    };

    environmentFile = mkOption {
      type = types.path;
      example = "/run/secrets/nautilus-accumulator.env";
      description = ''
        EnvironmentFile providing BINANCE_API_KEY and BINANCE_API_SECRET (Ed25519 — the
        secret is the Ed25519 private-key PEM). Use sops-nix templates so the secret is
        materialized at runtime, never in the Nix store.
      '';
    };

    user = mkOption {
      type = types.str;
      default = "nautilus";
      description = "User to run the service as.";
    };

    group = mkOption {
      type = types.str;
      default = "nautilus";
      description = "Primary group for the service user.";
    };
  };

  config = mkIf cfg.enable {
    users.users = mkIf (cfg.user == "nautilus") {
      nautilus = {
        isSystemUser = true;
        group = cfg.group;
        description = "nautilus-accumulator runner";
      };
    };
    users.groups = mkIf (cfg.group == "nautilus") { nautilus = { }; };

    systemd.services.nautilus-accumulator = {
      description = "Fear-driven crypto accumulation (NautilusTrader, Binance ${optionalString cfg.testnet "testnet"})";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        BINANCE_TESTNET = if cfg.testnet then "1" else "0";
        NAUTILUS_ENV = if cfg.testnet then "testnet" else "live";
        BINANCE_BAR = cfg.barSpec;
        ACC_INSTRUMENT = cfg.instrument;
        ACC_BASE_BUY_USD = toString cfg.baseBuyUsd;
        ACC_INTERVAL_BARS = toString cfg.intervalBars;
        ACC_MODE = cfg.mode;
        FNG_CSV = fngCsv;
        SSL_CERT_FILE = caBundle;
        NIX_SSL_CERT_FILE = caBundle;
        PYTHONUNBUFFERED = "1";
      };

      serviceConfig = {
        Type = "exec";
        ExecStartPre = "${pythonEnv}/bin/python ${app}/app/fetch_fng.py ${fngCsv}";
        ExecStart = "${pythonEnv}/bin/python ${app}/app/live_accumulation.py";
        EnvironmentFile = cfg.environmentFile;
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "30s";
        StateDirectory = "nautilus-accumulator";
        WorkingDirectory = "/var/lib/nautilus-accumulator";

        # Hardening
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
