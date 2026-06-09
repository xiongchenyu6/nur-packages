{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.nautilus-equity-trend;

  # Python env: nautilus-trader + the IB extra deps. The crypto services only need
  # `cfg.package`; the equity node additionally imports
  # `nautilus_trader.adapters.interactive_brokers`, which requires the `ibapi`
  # module (from nautilus-ibapi) and defusedxml. protobuf already comes
  # transitively from nautilus-trader. ps.psycopg2 mirrors the crypto modules
  # (trade_ledger is import-compatible even though this node does not write it yet).
  pythonEnv = pkgs.python313.withPackages (ps: [
    cfg.package
    cfg.ibapiPackage
    ps.defusedxml
    ps.psycopg2
  ]);

  app = pkgs.runCommand "nautilus-equity-trend-app" { } ''
    mkdir -p $out/app
    for f in live_honest_equity.py honest_trend_equity.py regime_gate.py kelly_sizer.py trade_ledger.py; do
      cp ${./.}/$f $out/app/$f
    done
  '';

  caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";
in
{
  options.services.nautilus-equity-trend = {
    enable = mkEnableOption "US-equity HonestTrend on NautilusTrader via Interactive Brokers (PAPER only)";

    package = mkOption {
      type = types.package;
      default = pkgs.nautilus-trader;
      defaultText = literalExpression "pkgs.nautilus-trader";
      description = "The nautilus-trader python package (from the xiongchenyu6 NUR overlay).";
    };

    ibapiPackage = mkOption {
      type = types.package;
      default = pkgs.nautilus-ibapi;
      defaultText = literalExpression "pkgs.nautilus-ibapi";
      description = ''
        The nautilus-ibapi python package (provides the `ibapi` module). This is the
        core dependency of the `nautilus-trader[ib]` extra and is required for the IB
        adapter import path. From the xiongchenyu6 NUR overlay.
      '';
    };

    instruments = mkOption {
      type = types.listOf types.str;
      default = [ "NVDA.NASDAQ" "AMD.NASDAQ" "QQQ.NASDAQ" ];
      description = ''
        Informational: the equity universe the runner trades. The list is currently
        hardcoded in live_honest_equity.py (INSTRUMENTS); this option documents the
        deployed universe and is NOT yet plumbed through an env var.
      '';
    };

    barSpec = mkOption {
      type = types.str;
      default = "1-HOUR-LAST-EXTERNAL";
      description = ''
        Bar type spec appended to each instrument (IB_BAR). The recommended live config
        is 1h EMA 50/100 (most robust across NVDA/AMD/QQQ). Use 1-DAY-LAST-EXTERNAL for
        a low-touch daily cadence.
      '';
    };

    emaFast = mkOption {
      type = types.int;
      default = 50;
      description = "Fast EMA period (EQ_EMA_FAST). Recommended live config: 50.";
    };

    emaSlow = mkOption {
      type = types.int;
      default = 100;
      description = "Slow EMA period (EQ_EMA_SLOW). Recommended live config: 100.";
    };

    account = mkOption {
      type = types.str;
      default = "DUQ654554";
      description = ''
        IB account id (IB_ACCOUNT). MUST be a paper account (starts with "DU"); the
        runner refuses to build otherwise (PAPER-ONLY guardrail). The IB exec client
        requires an explicit account id — the adapter does not auto-discover it.
      '';
    };

    clientId = mkOption {
      type = types.int;
      default = 8;
      description = "IB API client id (IB_CLIENT_ID). 8 = dedicated live node (5=download, 7=order test).";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = "IB Gateway/TWS host (IB_HOST). Default 127.0.0.1 — co-located with the Gateway.";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Optional EnvironmentFile carrying TIMESCALE_URL so the node persists fills /
        closed positions to quant.nautilus_trades (asset_class='equity'), mirroring the
        crypto nautilus-accumulator/nautilus-trend services. Point it at a sops template
        (e.g. config.sops.templates."nautilus-equity.env".path) holding
        `TIMESCALE_URL=postgres://quant:<pw>@db.panda.qzz.io:5432/api?sslmode=require`.
        When null the ledger is a no-op (TIMESCALE_URL unset) — trading is unaffected.
      '';
    };

    environment = mkOption {
      type = types.enum [ "testnet" "live" ];
      default = "testnet";
      description = ''
        NAUTILUS_ENV value recorded in quant.nautilus_trades.environment. The equity node
        is PAPER-only, so this stays "testnet" (the dashboard segregates testnet vs live).
      '';
    };

    port = mkOption {
      type = types.port;
      default = 4002;
      description = "IB Gateway/TWS port (IB_PORT). 4002 = Gateway paper; TWS paper = 7497.";
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
    # Create the user only if no co-located nautilus-* module already does (the crypto
    # modules create it; on an equity-only host this provides it).
    users.users = mkIf (cfg.user == "nautilus") {
      nautilus = mkDefault {
        isSystemUser = true;
        group = cfg.group;
        description = "nautilus runner";
      };
    };
    users.groups = mkIf (cfg.group == "nautilus") { nautilus = mkDefault { }; };

    systemd.services.nautilus-equity-trend = {
      description = "US-equity HonestTrend (NautilusTrader via Interactive Brokers, PAPER)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        # HARD GUARDRAIL: paper only. The runner additionally refuses any non-DU* account.
        IB_TRADING_MODE = "paper";
        IB_HOST = cfg.host;
        IB_PORT = toString cfg.port;
        IB_CLIENT_ID = toString cfg.clientId;
        IB_ACCOUNT = cfg.account;
        IB_BAR = cfg.barSpec;
        EQ_EMA_FAST = toString cfg.emaFast;
        EQ_EMA_SLOW = toString cfg.emaSlow;
        # Trade-ledger persistence: tags rows asset_class='equity' (set in the strategy)
        # and environment=NAUTILUS_ENV. TIMESCALE_URL comes from environmentFile (sops).
        NAUTILUS_ENV = cfg.environment;
        SSL_CERT_FILE = caBundle;
        NIX_SSL_CERT_FILE = caBundle;
        PYTHONUNBUFFERED = "1";
      };

      serviceConfig = {
        Type = "exec";
        ExecStart = "${pythonEnv}/bin/python ${app}/app/live_honest_equity.py";
        # Optional: carries TIMESCALE_URL so the node writes quant.nautilus_trades.
        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;
        User = cfg.user;
        Group = cfg.group;
        Restart = "on-failure";
        RestartSec = "30s";
        StateDirectory = "nautilus-equity-trend";
        WorkingDirectory = "/var/lib/nautilus-equity-trend";

        # Hardening (mirrors the crypto nautilus-* units).
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
