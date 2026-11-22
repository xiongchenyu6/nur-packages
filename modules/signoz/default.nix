{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.signoz;
  yamlFormat = pkgs.formats.yaml { };

  # Append a ClickHouse database path to a DSN while preserving any query string
  # (e.g. tcp://127.0.0.1:9000?username=signoz -> tcp://127.0.0.1:9000/signoz_logs?username=signoz).
  withClickhouseDb =
    dsn: db:
    let
      parts = splitString "?" dsn;
      base = removeSuffix "/" (head parts);
      query = optionalString (length parts > 1) ("?" + concatStringsSep "?" (tail parts));
    in
    "${base}/${db}${query}";

  keeperConfigFile = yamlFormat.generate "signoz-clickhouse-keeper.yaml" {
    listen_host = "127.0.0.1";
    logger = {
      console = true;
      level = "information";
    };
    keeper_server = {
      tcp_port = cfg.clickhouse.keeperPort;
      server_id = 0;
      log_storage_path = "/var/lib/clickhouse-keeper/coordination/log";
      snapshot_storage_path = "/var/lib/clickhouse-keeper/coordination/snapshots";
      four_letter_word_white_list = "*";
      coordination_settings = {
        force_sync = false;
        operation_timeout_ms = 10000;
        raft_logs_level = "warning";
        session_timeout_ms = 30000;
        snapshot_distance = 100000;
        snapshots_to_keep = 3;
      };
      raft_configuration = {
        server = [
          {
            id = 0;
            hostname = "127.0.0.1";
            port = cfg.clickhouse.keeperRaftPort;
          }
        ];
      };
    };
  };

  clickhouseFunctionsFile = yamlFormat.generate "signoz-clickhouse-functions.yaml" {
    functions = {
      name = "histogramQuantile";
      type = "executable";
      format = "CSV";
      command = "./histogramQuantile";
      return_type = "Float64";
      argument = [
        {
          name = "buckets";
          type = "Array(Float64)";
        }
        {
          name = "counts";
          type = "Array(Float64)";
        }
        {
          name = "quantile";
          type = "Float64";
        }
      ];
    };
  };

  defaultCollectorSettings = {
    connectors = {
      signozmeter = {
        metrics_flush_interval = "1h";
        dimensions = [
          { name = "service.name"; }
          { name = "deployment.environment"; }
          { name = "host.name"; }
        ];
      };
    };

    exporters = {
      clickhouselogsexporter = {
        dsn = withClickhouseDb cfg.clickhouse.dsn "signoz_logs";
        timeout = "45s";
        use_new_schema = true;
        sending_queue.enabled = false;
      };
      clickhousetraces = {
        datasource = withClickhouseDb cfg.clickhouse.dsn "signoz_traces";
        low_cardinal_exception_grouping = "\${env:LOW_CARDINAL_EXCEPTION_GROUPING}";
        timeout = "45s";
        use_new_schema = true;
        sending_queue.enabled = false;
      };
      metadataexporter = {
        dsn = withClickhouseDb cfg.clickhouse.dsn "signoz_metadata";
        enabled = true;
        timeout = "45s";
        cache.provider = "in_memory";
      };
      signozclickhousemeter = {
        dsn = withClickhouseDb cfg.clickhouse.dsn "signoz_meter";
        timeout = "45s";
        sending_queue.enabled = false;
      };
      signozclickhousemetrics = {
        dsn = withClickhouseDb cfg.clickhouse.dsn "signoz_metrics";
        timeout = "45s";
        sending_queue.enabled = false;
      };
    };

    extensions = {
      pprof.endpoint = "127.0.0.1:1777";
      signoz_health_check.endpoint = "127.0.0.1:13133";
    };

    processors = {
      batch = {
        send_batch_max_size = 55000;
        send_batch_size = 50000;
        timeout = "5s";
      };
      "batch/meter" = {
        send_batch_max_size = 25000;
        send_batch_size = 20000;
        timeout = "5s";
      };
      "filter/drop_stale" = {
        error_mode = "ignore";
        logs.log_record = [
          ''time_unix_nano != 0 and time < Now() - Duration("360h")''
          ''time_unix_nano == 0 and observed_time_unix_nano != 0 and observed_time < Now() - Duration("360h")''
        ];
        metrics.datapoint = [
          ''time_unix_nano != 0 and time < Now() - Duration("360h")''
        ];
        traces.span = [
          ''start_time_unix_nano != 0 and start_time < Now() - Duration("360h")''
        ];
      };
      signozllmpricing = {
        attrs = {
          cache_read = "gen_ai.usage.cache_read.input_tokens";
          cache_write = "gen_ai.usage.cache_creation.input_tokens";
          "in" = "gen_ai.usage.input_tokens";
          model = "gen_ai.request.model";
          out = "gen_ai.usage.output_tokens";
        };
        default_pricing.rules = [ ];
        output_attrs = {
          cache_read = "signoz.gen_ai.usage.cache_read.input_tokens.cost";
          cache_write = "signoz.gen_ai.usage.cache_write.input_tokens.cost";
          "in" = "signoz.gen_ai.usage.input_tokens.cost";
          out = "signoz.gen_ai.usage.output_tokens.cost";
          total = "signoz.gen_ai.usage.tokens.cost";
        };
      };
      signozlogsnormalizer = { };
      signozspanmapper.groups = [ ];
      "signozspanmetrics/delta" = {
        aggregation_temporality = "AGGREGATION_TEMPORALITY_DELTA";
        dimensions = [
          {
            name = "service.namespace";
            default = "default";
          }
          {
            name = "deployment.environment";
            default = "default";
          }
          { name = "signoz.collector.id"; }
          { name = "service.version"; }
        ];
        dimensions_cache_size = 100000;
        enable_exp_histogram = true;
        latency_histogram_buckets = [
          "100us"
          "1ms"
          "2ms"
          "6ms"
          "10ms"
          "50ms"
          "100ms"
          "250ms"
          "500ms"
          "1000ms"
          "1400ms"
          "2000ms"
          "5s"
          "10s"
          "20s"
          "40s"
          "60s"
        ];
        metrics_exporter = "signozclickhousemetrics";
        metrics_flush_interval = "60s";
      };
    };

    receivers = {
      otlp.protocols = {
        grpc.endpoint = "${cfg.collector.listenAddress}:${toString cfg.collector.otlpGrpcPort}";
        http.endpoint = "${cfg.collector.listenAddress}:${toString cfg.collector.otlpHttpPort}";
      };
    };

    service = {
      extensions = [
        "signoz_health_check"
        "pprof"
      ];
      pipelines = {
        logs = {
          receivers = [ "otlp" ];
          processors = [
            "signozlogsnormalizer"
            "filter/drop_stale"
            "batch"
          ];
          exporters = [
            "clickhouselogsexporter"
            "signozmeter"
            "metadataexporter"
          ];
        };
        metrics = {
          receivers = [ "otlp" ];
          processors = [
            "filter/drop_stale"
            "batch"
          ];
          exporters = [
            "signozclickhousemetrics"
            "signozmeter"
            "metadataexporter"
          ];
        };
        "metrics/meter" = {
          receivers = [ "signozmeter" ];
          processors = [ "batch/meter" ];
          exporters = [ "signozclickhousemeter" ];
        };
        traces = {
          receivers = [ "otlp" ];
          processors = [
            "signozspanmetrics/delta"
            "signozspanmapper"
            "signozllmpricing"
            "filter/drop_stale"
            "batch"
          ];
          exporters = [
            "clickhousetraces"
            "signozmeter"
            "metadataexporter"
          ];
        };
      };
      telemetry.logs.encoding = "json";
    };
  };

  collectorConfigFile = yamlFormat.generate "signoz-otel-collector.yaml" (
    recursiveUpdate defaultCollectorSettings cfg.collector.extraSettings
  );

  opampConfigFile = yamlFormat.generate "signoz-otel-collector-opamp.yaml" {
    server_endpoint = "ws://127.0.0.1:4320/v1/opamp";
  };

  signozConfigFile = yamlFormat.generate "signoz-config.yaml" cfg.settings;

  oneDayTtl = {
    ttl = mkDefault "event_date + INTERVAL 1 DAY DELETE";
  };
in
{
  options.services.signoz = {
    enable = mkEnableOption "SigNoz observability platform (Community Edition)";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../../pkgs/signoz/package.nix { };
      defaultText = literalExpression "pkgs.callPackage ../../pkgs/signoz/package.nix { }";
      description = "The SigNoz server package to use.";
    };

    collectorPackage = mkOption {
      type = types.package;
      default = pkgs.callPackage ../../pkgs/signoz-otel-collector/package.nix { };
      defaultText = literalExpression "pkgs.callPackage ../../pkgs/signoz-otel-collector/package.nix { }";
      description = "The signoz-otel-collector package used for ingestion and ClickHouse schema migrations.";
    };

    histogramQuantilePackage = mkOption {
      type = types.package;
      default = pkgs.callPackage ../../pkgs/signoz-histogram-quantile/package.nix { };
      defaultText = literalExpression "pkgs.callPackage ../../pkgs/signoz-histogram-quantile/package.nix { }";
      description = "The histogramQuantile ClickHouse executable UDF package.";
    };

    listenAddress = mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = "Address on which the SigNoz web UI and API server listen.";
    };

    port = mkOption {
      type = types.port;
      default = 8080;
      description = "Port on which the SigNoz web UI and API server listen.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/signoz";
      description = "Directory for SigNoz persistent state (SQLite DB and collector runtime config).";
    };

    user = mkOption {
      type = types.str;
      default = "signoz";
      description = "System user under which SigNoz and its collector run.";
    };

    group = mkOption {
      type = types.str;
      default = "signoz";
      description = "System group under which SigNoz and its collector run.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the SigNoz UI/API port in the firewall.";
    };

    runMigrations = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to run ClickHouse schema migrations before starting SigNoz and the collector.";
    };

    sqlStore = {
      provider = mkOption {
        type = types.enum [
          "sqlite"
          "postgres"
        ];
        default = "sqlite";
        description = "Metadata database backend for SigNoz.";
      };

      sqlitePath = mkOption {
        type = types.str;
        default = "${cfg.dataDir}/signoz.db";
        defaultText = literalExpression ''"''${config.services.signoz.dataDir}/signoz.db"'';
        description = "Path to the SQLite database file when sqlStore.provider is sqlite.";
      };

      postgresDsnFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/run/secrets/signoz-postgres-dsn";
        description = ''
          Path to a file containing the PostgreSQL DSN (e.g.
          postgres://user:pass@localhost:5432/signoz?sslmode=disable) when
          sqlStore.provider is postgres. Loaded at runtime via systemd credentials.
        '';
      };
    };

    clickhouse = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = ''
          Whether to manage a local ClickHouse server and ClickHouse Keeper
          configured for SigNoz (including the histogramQuantile UDF).
          Disable this if connecting to an external ClickHouse cluster.
        '';
      };

      package = mkOption {
        type = types.package;
        default = pkgs.clickhouse;
        defaultText = literalExpression "pkgs.clickhouse";
        description = "ClickHouse package used for both ClickHouse server and ClickHouse Keeper.";
      };

      tcpPort = mkOption {
        type = types.port;
        default = 9000;
        description = "Native TCP port for the managed local ClickHouse server.";
      };

      httpPort = mkOption {
        type = types.port;
        default = 8123;
        description = "HTTP interface port for the managed local ClickHouse server.";
      };

      keeperPort = mkOption {
        type = types.port;
        default = 9181;
        description = "Client TCP port for the managed local ClickHouse Keeper.";
      };

      keeperRaftPort = mkOption {
        type = types.port;
        default = 9234;
        description = "Internal Raft port for the managed local ClickHouse Keeper.";
      };

      dsn = mkOption {
        type = types.str;
        default = "tcp://127.0.0.1:${toString cfg.clickhouse.tcpPort}";
        defaultText = literalExpression ''"tcp://127.0.0.1:''${toString config.services.signoz.clickhouse.tcpPort}"'';
        description = "ClickHouse native TCP DSN used by SigNoz, the migrator, and the collector.";
      };

      clusterName = mkOption {
        type = types.str;
        default = "cluster";
        description = "ClickHouse cluster name configured in remote_servers and used for migrations.";
      };
    };

    collector = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to run the SigNoz OpenTelemetry Collector service.";
      };

      listenAddress = mkOption {
        type = types.str;
        default = "0.0.0.0";
        description = "Address on which the OTLP gRPC and HTTP receivers listen.";
      };

      otlpGrpcPort = mkOption {
        type = types.port;
        default = 4317;
        description = "Port for the OTLP gRPC receiver.";
      };

      otlpHttpPort = mkOption {
        type = types.port;
        default = 4318;
        description = "Port for the OTLP HTTP receiver.";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to open the OTLP gRPC and HTTP ports in the firewall.";
      };

      extraSettings = mkOption {
        inherit (yamlFormat) type;
        default = { };
        description = "Extra YAML settings recursively merged into the default signoz-otel-collector configuration.";
      };

      environment = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Additional environment variables passed to signoz-otel-collector.";
      };
    };

    settings = mkOption {
      inherit (yamlFormat) type;
      default = { };
      description = ''
        Optional SigNoz YAML configuration passed via --config.
        See conf/example.yaml in the SigNoz repository for all available keys.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        SIGNOZ_GLOBAL_EXTERNAL_URL = "https://signoz.example.com";
      };
      description = "Additional SIGNOZ_* environment variables passed to the SigNoz server.";
    };

    environmentFiles = mkOption {
      type = types.listOf types.path;
      default = [ ];
      example = [ "/run/secrets/signoz.env" ];
      description = "systemd EnvironmentFile paths loaded into the SigNoz server (for SMTP, OAuth, or other secrets).";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.sqlStore.provider != "postgres" || cfg.sqlStore.postgresDsnFile != null;
        message = "services.signoz: sqlStore.postgresDsnFile must be set when sqlStore.provider is \"postgres\".";
      }
    ];

    # Local ClickHouse + ClickHouse Keeper managed for single-node SigNoz deployments.
    services.clickhouse = mkIf cfg.clickhouse.enable {
      enable = true;
      package = mkDefault cfg.clickhouse.package;
      serverConfig = {
        listen_host = mkDefault "127.0.0.1";
        tcp_port = mkDefault cfg.clickhouse.tcpPort;
        http_port = mkDefault cfg.clickhouse.httpPort;
        display_name = mkDefault cfg.clickhouse.clusterName;
        distributed_ddl.path = mkDefault "/clickhouse/task_queue/ddl";
        macros = {
          shard = mkDefault "00";
          replica = mkDefault "00";
        };
        remote_servers.${cfg.clickhouse.clusterName}.shard = [
          {
            replica = [
              {
                host = "127.0.0.1";
                port = cfg.clickhouse.tcpPort;
              }
            ];
          }
        ];
        zookeeper.node = [
          {
            host = "127.0.0.1";
            port = cfg.clickhouse.keeperPort;
          }
        ];
        user_scripts_path = "${cfg.histogramQuantilePackage}/bin/";
        user_defined_executable_functions_config = "*functions.yaml";

        # Keep ClickHouse internal system tables bounded on single-node deployments.
        query_log = oneDayTtl // {
          flush_interval_milliseconds = mkDefault 30000;
          partition_by = mkDefault "toYYYYMM(event_date)";
        };
        query_thread_log = oneDayTtl;
        query_metric_log = oneDayTtl;
        query_views_log = oneDayTtl;
        part_log = oneDayTtl;
        metric_log = oneDayTtl // {
          flush_interval_milliseconds = mkDefault 30000;
        };
        asynchronous_metric_log = oneDayTtl;
        trace_log = oneDayTtl // {
          flush_interval_milliseconds = mkDefault 30000;
        };
        error_log = oneDayTtl;
        latency_log = oneDayTtl;
        processors_profile_log = oneDayTtl // {
          flush_interval_milliseconds = mkDefault 30000;
        };
        session_log = oneDayTtl;
        text_log = oneDayTtl // {
          flush_interval_milliseconds = mkDefault 30000;
        };
        zookeeper_log = oneDayTtl;
      };
    };

    environment.etc."clickhouse-server/signoz_functions.yaml" = mkIf cfg.clickhouse.enable {
      source = clickhouseFunctionsFile;
    };

    systemd = {
      services = {
        signoz-clickhouse-keeper = mkIf cfg.clickhouse.enable {
          description = "ClickHouse Keeper for SigNoz";
          wantedBy = [ "multi-user.target" ];
          before = [ "clickhouse.service" ];
          after = [
            "network-online.target"
            "time-sync.target"
          ];
          wants = [
            "network-online.target"
            "time-sync.target"
          ];

          serviceConfig = {
            Type = "simple";
            User = "clickhouse";
            Group = "clickhouse";
            StateDirectory = "clickhouse-keeper";
            RuntimeDirectory = "clickhouse-keeper";
            ExecStart = "${cfg.clickhouse.package}/bin/clickhouse keeper --config=${keeperConfigFile} --pid-file=/run/clickhouse-keeper/clickhouse-keeper.pid";
            LimitNOFILE = 500000;
            Restart = "always";
            RestartSec = "5s";
          };
        };

        clickhouse = mkIf cfg.clickhouse.enable {
          after = [ "signoz-clickhouse-keeper.service" ];
          wants = [ "signoz-clickhouse-keeper.service" ];
          serviceConfig.LimitNOFILE = mkDefault 500000;
        };

        signoz-migrator = mkIf cfg.runMigrations {
          description = "SigNoz ClickHouse TelemetryStore Schema Migrator";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ] ++ optional cfg.clickhouse.enable "clickhouse.service";
          wants = [ "network-online.target" ] ++ optional cfg.clickhouse.enable "clickhouse.service";

          environment = {
            SIGNOZ_OTEL_COLLECTOR_CLICKHOUSE_DSN = cfg.clickhouse.dsn;
            SIGNOZ_OTEL_COLLECTOR_CLICKHOUSE_CLUSTER = cfg.clickhouse.clusterName;
            SIGNOZ_OTEL_COLLECTOR_TIMEOUT = "10m";
          };

          script = ''
            ${getExe cfg.collectorPackage} migrate bootstrap --clickhouse-cluster=${escapeShellArg cfg.clickhouse.clusterName}
            ${getExe cfg.collectorPackage} migrate sync up --clickhouse-cluster=${escapeShellArg cfg.clickhouse.clusterName}
            ${getExe cfg.collectorPackage} migrate async up --clickhouse-cluster=${escapeShellArg cfg.clickhouse.clusterName}
          '';

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = cfg.user;
            Group = cfg.group;
            ExecStartPre = "${getExe cfg.collectorPackage} migrate ready";
            Restart = "on-failure";
            RestartSec = "5s";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
          };
        };

        signoz = {
          description = "SigNoz Observability Platform";
          wantedBy = [ "multi-user.target" ];
          after = [
            "network-online.target"
          ]
          ++ optional cfg.clickhouse.enable "clickhouse.service"
          ++ optional cfg.runMigrations "signoz-migrator.service";
          wants = [ "network-online.target" ] ++ optional cfg.clickhouse.enable "clickhouse.service";
          requires = optional cfg.runMigrations "signoz-migrator.service";

          environment = {
            SIGNOZ_APISERVER_ADDRESS = "${cfg.listenAddress}:${toString cfg.port}";
            SIGNOZ_WEB_ENABLED = "true";
            SIGNOZ_WEB_DIRECTORY = "${cfg.package}/share/signoz/web";
            SIGNOZ_ALERTMANAGER_SIGNOZ_TEMPLATES = "${cfg.package}/share/signoz/templates/alertmanager/*.gotmpl";
            SIGNOZ_EMAILING_TEMPLATES_DIRECTORY = "${cfg.package}/share/signoz/templates/email";
            SIGNOZ_TELEMETRYSTORE_PROVIDER = "clickhouse";
            SIGNOZ_TELEMETRYSTORE_CLICKHOUSE_DSN = cfg.clickhouse.dsn;
            SIGNOZ_TELEMETRYSTORE_CLICKHOUSE_CLUSTER = cfg.clickhouse.clusterName;
            SIGNOZ_SQLSTORE_PROVIDER = cfg.sqlStore.provider;
          }
          // optionalAttrs (cfg.sqlStore.provider == "sqlite") {
            SIGNOZ_SQLSTORE_SQLITE_PATH = cfg.sqlStore.sqlitePath;
          }
          // cfg.environment;

          script = ''
            ${optionalString (cfg.sqlStore.provider == "postgres") ''
              SIGNOZ_SQLSTORE_POSTGRES_DSN="$(< "$CREDENTIALS_DIRECTORY/postgres-dsn")"
              if [ -z "$SIGNOZ_SQLSTORE_POSTGRES_DSN" ]; then
                echo "signoz: ${toString cfg.sqlStore.postgresDsnFile} is empty" >&2
                exit 1
              fi
              export SIGNOZ_SQLSTORE_POSTGRES_DSN
            ''}
            exec ${getExe cfg.package} server${
              optionalString (cfg.settings != { }) " --config=${signozConfigFile}"
            }
          '';

          serviceConfig = {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = cfg.dataDir;
            StateDirectory = mkIf (cfg.dataDir == "/var/lib/signoz") "signoz";
            StateDirectoryMode = "0750";
            KillMode = "mixed";
            Restart = "on-failure";
            RestartSec = "5s";

            LoadCredential = optional (
              cfg.sqlStore.provider == "postgres"
            ) "postgres-dsn:${toString cfg.sqlStore.postgresDsnFile}";
            EnvironmentFile = cfg.environmentFiles;

            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [ cfg.dataDir ];
            ProtectControlGroups = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            RestrictSUIDSGID = true;
          };
        };

        signoz-otel-collector = mkIf cfg.collector.enable {
          description = "SigNoz OpenTelemetry Collector";
          wantedBy = [ "multi-user.target" ];
          after = [
            "network-online.target"
            "signoz.service"
          ]
          ++ optional cfg.runMigrations "signoz-migrator.service";
          wants = [
            "network-online.target"
            "signoz.service"
          ];
          requires = optional cfg.runMigrations "signoz-migrator.service";

          environment = {
            SIGNOZ_OTEL_COLLECTOR_CLICKHOUSE_DSN = cfg.clickhouse.dsn;
            SIGNOZ_OTEL_COLLECTOR_CLICKHOUSE_CLUSTER = cfg.clickhouse.clusterName;
            SIGNOZ_OTEL_COLLECTOR_TIMEOUT = "10m";
            LOW_CARDINAL_EXCEPTION_GROUPING = "false";
          }
          // cfg.collector.environment;

          preStart = ''
            mkdir -p ${escapeShellArg "${cfg.dataDir}/collector"}
            ${getExe cfg.collectorPackage} migrate sync check --clickhouse-cluster=${escapeShellArg cfg.clickhouse.clusterName}
          '';

          serviceConfig = {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            WorkingDirectory = cfg.dataDir;
            ExecStart = "${getExe cfg.collectorPackage} --config=${collectorConfigFile} --manager-config=${opampConfigFile} --copy-path=${cfg.dataDir}/collector/ingester.yaml";
            KillMode = "mixed";
            Restart = "on-failure";
            RestartSec = "5s";

            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [ cfg.dataDir ];
            ProtectControlGroups = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            RestrictSUIDSGID = true;
          };
        };
      };

      tmpfiles.rules = mkIf (cfg.dataDir != "/var/lib/signoz") [
        "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      ];
    };

    users.users.${cfg.user} = mkIf (cfg.user == "signoz") {
      description = "SigNoz service user";
      isSystemUser = true;
      inherit (cfg) group;
      home = cfg.dataDir;
    };

    users.groups.${cfg.group} = mkIf (cfg.group == "signoz") { };

    networking.firewall.allowedTCPPorts =
      optional cfg.openFirewall cfg.port
      ++ optionals (cfg.collector.enable && cfg.collector.openFirewall) [
        cfg.collector.otlpGrpcPort
        cfg.collector.otlpHttpPort
      ];

    environment.systemPackages = [
      cfg.package
      cfg.collectorPackage
    ];
  };
}
