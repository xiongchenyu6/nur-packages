{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.hashtopolis-agent;

  hashtopolisAgentPkg = pkgs.callPackage ../../pkgs/hashtopolis-agent/package.nix { };

  # Configuration file for the agent
  agentConfig = pkgs.writeText "agent.config" ''
    {
      "url": "${cfg.serverUrl}",
      "voucher": "${cfg.voucher}",
      "uuid": "${cfg.uuid}",
      "files-path": "${cfg.dataDir}/files",
      "hashlist-path": "${cfg.dataDir}/hashlists",
      "zaps-path": "${cfg.dataDir}/zaps",
      "crackers-path": "${cfg.crackersPath}",
      "prince-path": "${cfg.princePath}",
      "preprocessors-path": "${cfg.preprocessorsPath}",
      "use-native-hashcat": ${if cfg.useNativeHashcat then "true" else "false"},
      "allow-piping": ${if cfg.allowPiping then "true" else "false"},
      "disable-update": true
    }
  '';

in {
  options.services.hashtopolis-agent = {
    enable = mkEnableOption "Hashtopolis agent - distributed hashcat task worker";

    package = mkOption {
      type = types.package;
      default = hashtopolisAgentPkg;
      description = "Hashtopolis agent package to use";
    };

    serverUrl = mkOption {
      type = types.str;
      example = "http://hashtopolis.example.com:8080/api/server.php";
      description = "URL of the Hashtopolis server API endpoint";
    };

    voucher = mkOption {
      type = types.str;
      default = "";
      description = "Voucher token for agent registration (leave empty after registration)";
    };

    uuid = mkOption {
      type = types.str;
      default = "";
      description = "Agent UUID (automatically generated after registration)";
    };

    dataDir = mkOption {
      type = types.path;
      default = "/var/lib/hashtopolis-agent";
      description = "Directory where the agent stores its data";
    };

    crackersPath = mkOption {
      type = types.path;
      default = "/var/lib/hashtopolis-agent/crackers";
      description = "Directory containing hashcat and other cracking tools";
    };

    princePath = mkOption {
      type = types.path;
      default = "/var/lib/hashtopolis-agent/prince";
      description = "Directory containing PRINCE preprocessor";
    };

    preprocessorsPath = mkOption {
      type = types.path;
      default = "/var/lib/hashtopolis-agent/preprocessors";
      description = "Directory containing preprocessors";
    };

    useNativeHashcat = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to use system-installed hashcat instead of downloading";
    };

    hashcatPackage = mkOption {
      type = types.nullOr types.package;
      default = null;
      example = "pkgs.hashcat";
      description = "Hashcat package to use when useNativeHashcat is true";
    };

    allowPiping = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to allow piping mode for hashcat";
    };

    deviceTypes = mkOption {
      type = types.listOf (types.enum [ "cpu" "gpu" ]);
      default = [ "cpu" ];
      description = "Device types to use for cracking (cpu, gpu, or both)";
    };

    gpuDevices = mkOption {
      type = types.listOf types.int;
      default = [];
      example = [ 1 2 ];
      description = "GPU device IDs to use (empty means all available)";
    };

    cpuOnly = mkOption {
      type = types.bool;
      default = false;
      description = "Force CPU-only mode even if GPUs are available";
    };

    memoryLimit = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "4G";
      description = "Memory limit for the agent process";
    };

    cpuQuota = mkOption {
      type = types.nullOr types.int;
      default = null;
      example = 50;
      description = "CPU quota percentage (1-100)";
    };

    user = mkOption {
      type = types.str;
      default = "hashtopolis-agent";
      description = "User under which the agent runs";
    };

    group = mkOption {
      type = types.str;
      default = "hashtopolis-agent";
      description = "Group under which the agent runs";
    };

    autoStart = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to start the agent automatically on boot";
    };

    restartOnFailure = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to restart the agent on failure";
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to environment file with additional variables";
    };
  };

  config = mkIf cfg.enable {
    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      extraGroups = [ "video" ]; # For GPU access
    };

    users.groups.${cfg.group} = {};

    # Create necessary directories
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/files 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/hashlists 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.dataDir}/zaps 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.crackersPath} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.princePath} 0750 ${cfg.user} ${cfg.group} -"
      "d ${cfg.preprocessorsPath} 0750 ${cfg.user} ${cfg.group} -"
    ];

    # Setup systemd service
    systemd.services.hashtopolis-agent = {
      description = "Hashtopolis Agent";
      wantedBy = optionals cfg.autoStart [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        HOME = cfg.dataDir;
        HASHTOPOLIS_CONFIG = "${agentConfig}";
      } // optionalAttrs (cfg.cpuOnly) {
        CUDA_VISIBLE_DEVICES = "-1"; # Disable CUDA
      } // optionalAttrs (cfg.gpuDevices != []) {
        CUDA_VISIBLE_DEVICES = concatStringsSep "," (map toString cfg.gpuDevices);
      };

      preStart = ''
        # Copy config file
        cp ${agentConfig} ${cfg.dataDir}/config.json
        chown ${cfg.user}:${cfg.group} ${cfg.dataDir}/config.json

        # Link hashcat if using native
        ${optionalString (cfg.useNativeHashcat && cfg.hashcatPackage != null) ''
          ln -sf ${cfg.hashcatPackage}/bin/hashcat ${cfg.crackersPath}/hashcat
        ''}
      '';

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        ExecStart = "${cfg.package}/bin/hashtopolis-agent";
        Restart = mkIf cfg.restartOnFailure "always";
        RestartSec = "30s";

        # Resource limits
        MemoryMax = mkIf (cfg.memoryLimit != null) cfg.memoryLimit;
        CPUQuota = mkIf (cfg.cpuQuota != null) "${toString cfg.cpuQuota}%";

        # Security hardening
        PrivateTmp = true;
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];

        # Allow GPU access if needed
        PrivateDevices = mkIf (elem "gpu" cfg.deviceTypes) false;

        # Load environment file if specified
        EnvironmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;
      };
    };

    # Install hashcat if requested
    environment.systemPackages = mkIf (cfg.useNativeHashcat && cfg.hashcatPackage != null) [
      cfg.hashcatPackage
    ];

    # GPU support - ensure necessary drivers are available
    hardware.graphics = mkIf (elem "gpu" cfg.deviceTypes) {
      enable = true;
    };
  };
}