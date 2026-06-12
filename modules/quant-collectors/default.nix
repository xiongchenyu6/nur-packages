{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.quant-collectors;

  # Plain CPython env — these collectors only need requests + psycopg2 (the DB is
  # local on this host). No nautilus-trader.
  pythonEnv = pkgs.python313.withPackages (ps: [
    ps.requests
    ps.psycopg2
  ]);

  app = pkgs.runCommand "quant-collectors-app" { } ''
    mkdir -p $out/app
    cp ${./.}/news_collector.py $out/app/news_collector.py
    cp ${./.}/stress_index.py $out/app/stress_index.py
  '';

  caBundle = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

  mkCollector = name: script: description: {
    inherit description;
    after = [
      "network-online.target"
      "postgresql.service"
    ];
    wants = [ "network-online.target" ];

    environment = {
      SSL_CERT_FILE = caBundle;
      NIX_SSL_CERT_FILE = caBundle;
      PYTHONUNBUFFERED = "1";
    };

    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pythonEnv}/bin/python ${app}/app/${script}";
      EnvironmentFile = cfg.environmentFile;
      User = cfg.user;
      Group = cfg.group;

      # Same hardening profile as the nautilus-* services.
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
in
{
  options.services.quant-collectors = {
    enable = mkEnableOption "quant data collectors (news RSS + market stress index) writing to the local TimescaleDB";

    environmentFile = mkOption {
      type = types.path;
      example = "/run/secrets/quant-collectors.env";
      description = ''
        EnvironmentFile providing TIMESCALE_URL (postgres DSN for the quant role).
        Use sops-nix templates so the password never lands in the Nix store.
      '';
    };

    newsInterval = mkOption {
      type = types.str;
      default = "*:04/20";
      description = "OnCalendar spec for the news collector (default: every 20 min).";
    };

    stressInterval = mkOption {
      type = types.str;
      default = "*:31";
      description = "OnCalendar spec for the stress index (default: hourly at :31).";
    };

    user = mkOption {
      type = types.str;
      default = "nautilus";
      description = "User to run the collectors as (shared with the nautilus services).";
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
        description = mkDefault "nautilus services runner";
      };
    };
    users.groups = mkIf (cfg.group == "nautilus") { nautilus = { }; };

    systemd.services.quant-news-collector =
      mkCollector "quant-news-collector" "news_collector.py"
        "Quant market news collector — curated RSS → quant.news_items (headlines verbatim)";
    systemd.services.quant-stress-index =
      mkCollector "quant-stress-index" "stress_index.py"
        "Quant market stress index — explainable FNG/VIX/funding/breadth composite → quant.market_stress";

    systemd.timers.quant-news-collector = {
      description = "News collection every 20 minutes";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.newsInterval;
        Persistent = true;
      };
    };
    systemd.timers.quant-stress-index = {
      description = "Market stress index hourly";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = cfg.stressInterval;
        Persistent = true;
      };
    };
  };
}
