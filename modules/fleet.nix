{ pkgs, config, lib, ... }:
with lib;
let
  cfg = config.services.fleet;
in {
  options.services = {
    fleet = {
      enable = mkEnableOption "Enables Fleet GitOps controller service";
      
      package = mkOption {
        type = types.package;
        default = pkgs.fleet;
        description = "Fleet package to use";
      };

      namespace = mkOption {
        type = types.str;
        default = "cattle-fleet-system";
        description = "Kubernetes namespace to watch for Fleet resources";
      };

      kubeconfig = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to kubeconfig file";
      };

      disableMetrics = mkOption {
        type = types.bool;
        default = false;
        description = "Disable metrics endpoint";
      };

      shardId = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Only manage resources labeled with a specific shard ID";
      };

      enableLeaderElection = mkOption {
        type = types.bool;
        default = true;
        description = "Enable leader election for controller manager";
      };

      debug = mkOption {
        type = types.bool;
        default = false;
        description = "Enable debug logging";
      };

      debugLevel = mkOption {
        type = types.int;
        default = 0;
        description = "Debug level (0-9)";
      };

      metricsBindAddress = mkOption {
        type = types.str;
        default = ":8080";
        description = "Bind address for metrics endpoint";
      };

      healthProbeBindAddress = mkOption {
        type = types.str;
        default = ":8081";
        description = "Bind address for health probe endpoint";
      };

      reconcilerWorkers = {
        bundle = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Number of bundle reconciler workers";
        };
        bundleDeployment = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Number of bundle deployment reconciler workers";
        };
        cluster = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Number of cluster reconciler workers";
        };
        clusterGroup = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Number of cluster group reconciler workers";
        };
        imageScan = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Number of image scan reconciler workers";
        };
        schedule = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Number of schedule reconciler workers";
        };
        content = mkOption {
          type = types.nullOr types.int;
          default = null;
          description = "Number of content reconciler workers";
        };
      };

      extraArgs = mkOption {
        type = types.listOf types.str;
        default = [];
        description = "Extra arguments to pass to fleet controller";
      };

      extraEnv = mkOption {
        type = types.attrsOf types.str;
        default = {};
        description = "Extra environment variables for the fleet controller";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.fleet = {
      description = "Fleet GitOps Controller";
      wantedBy = [ "multi-user.target" ];
      after = [ "networking.target" ];
      
      environment = {
        NAMESPACE = cfg.namespace;
        FLEET_METRICS_BIND_ADDRESS = cfg.metricsBindAddress;
        FLEET_HEALTHPROBE_BIND_ADDRESS = cfg.healthProbeBindAddress;
      } // optionalAttrs (cfg.kubeconfig != null) {
        KUBECONFIG = toString cfg.kubeconfig;
      } // optionalAttrs (cfg.reconcilerWorkers.bundle != null) {
        BUNDLE_RECONCILER_WORKERS = toString cfg.reconcilerWorkers.bundle;
      } // optionalAttrs (cfg.reconcilerWorkers.bundleDeployment != null) {
        BUNDLEDEPLOYMENT_RECONCILER_WORKERS = toString cfg.reconcilerWorkers.bundleDeployment;
      } // optionalAttrs (cfg.reconcilerWorkers.cluster != null) {
        CLUSTER_RECONCILER_WORKERS = toString cfg.reconcilerWorkers.cluster;
      } // optionalAttrs (cfg.reconcilerWorkers.clusterGroup != null) {
        CLUSTERGROUP_RECONCILER_WORKERS = toString cfg.reconcilerWorkers.clusterGroup;
      } // optionalAttrs (cfg.reconcilerWorkers.imageScan != null) {
        IMAGESCAN_RECONCILER_WORKERS = toString cfg.reconcilerWorkers.imageScan;
      } // optionalAttrs (cfg.reconcilerWorkers.schedule != null) {
        SCHEDULE_RECONCILER_WORKERS = toString cfg.reconcilerWorkers.schedule;
      } // optionalAttrs (cfg.reconcilerWorkers.content != null) {
        CONTENT_RECONCILER_WORKERS = toString cfg.reconcilerWorkers.content;
      } // cfg.extraEnv;

      serviceConfig = {
        Type = "simple";
        User = "fleet";
        Group = "fleet";
        Restart = "always";
        RestartSec = "10s";
        WorkingDirectory = "/var/lib/fleet";
        StateDirectory = "fleet";
        RuntimeDirectory = "fleet";
        
        # Security settings
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectSystem = "strict";
        ReadWritePaths = [ "/var/lib/fleet" ];
      };

      script = let
        args = [
          "--namespace=${cfg.namespace}"
        ] ++ optionals cfg.disableMetrics [
          "--disable-metrics"
        ] ++ optionals (cfg.shardId != null) [
          "--shard-id=${cfg.shardId}"
        ] ++ optionals (!cfg.enableLeaderElection) [
          "--leader-elect=false"
        ] ++ optionals cfg.debug [
          "--debug"
          "--debug-level=${toString cfg.debugLevel}"
        ] ++ optionals (cfg.kubeconfig != null) [
          "--kubeconfig=${cfg.kubeconfig}"
        ] ++ cfg.extraArgs;
      in ''
        exec ${cfg.package}/bin/fleetcontroller ${escapeShellArgs args}
      '';
    };

    users.users.fleet = {
      description = "Fleet GitOps service user";
      isSystemUser = true;
      group = "fleet";
      home = "/var/lib/fleet";
      createHome = true;
    };

    users.groups.fleet = {};

    # Open firewall ports for metrics and health probe if not on localhost
    networking.firewall.allowedTCPPorts = mkIf (
      !hasPrefix "127.0.0.1:" cfg.metricsBindAddress && 
      !hasPrefix "localhost:" cfg.metricsBindAddress
    ) (
      let
        metricsPort = toInt (last (splitString ":" cfg.metricsBindAddress));
        healthPort = toInt (last (splitString ":" cfg.healthProbeBindAddress));
      in
      [ metricsPort healthPort ]
    );
  };
}