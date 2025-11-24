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
    # Enable nix-ld for running downloaded binaries
    programs.nix-ld = {
      enable = true;
      libraries = with pkgs; [
        stdenv.cc.cc.lib
        zlib
        openssl
        glibc
      ] ++ optionals (elem "gpu" cfg.deviceTypes) [
        cudatoolkit
        linuxPackages.nvidia_x11
        ocl-icd
      ];
    };

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
      "d ${cfg.crackersPath}/temp 0750 ${cfg.user} ${cfg.group} -"
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
        # Point to the config file in the data directory
        HASHTOPOLIS_CONFIG = "${cfg.dataDir}/config.json";
      } // optionalAttrs (cfg.cpuOnly) {
        CUDA_VISIBLE_DEVICES = "-1"; # Disable CUDA
      } // optionalAttrs (cfg.gpuDevices != []) {
        CUDA_VISIBLE_DEVICES = concatStringsSep "," (map toString cfg.gpuDevices);
      } // optionalAttrs (elem "gpu" cfg.deviceTypes) {
        CUDA_PATH = "${pkgs.cudatoolkit}";
        LD_LIBRARY_PATH = lib.makeLibraryPath ([
          pkgs.cudatoolkit
          pkgs.linuxPackages.nvidia_x11
          pkgs.ocl-icd
        ]);
      };

      path = with pkgs; [
        pciutils  # lspci for hardware detection
        p7zip     # 7z/7zr for extracting archives
      ] ++ optionals (elem "gpu" cfg.deviceTypes) [
        cudatoolkit
        ocl-icd
      ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        StateDirectory = "hashtopolis-agent";
        StateDirectoryMode = "0750";

        # Run preStart as root to set up files
        ExecStartPre = let
          preStartScript = pkgs.writeShellScript "hashtopolis-agent-prestart" ''
            # Ensure all required directories exist
            mkdir -p ${cfg.dataDir}/{files,hashlists,zaps}
            mkdir -p ${cfg.crackersPath}/temp
            mkdir -p ${cfg.princePath}
            mkdir -p ${cfg.preprocessorsPath}

            # Set proper ownership
            chown -R ${cfg.user}:${cfg.group} ${cfg.dataDir}

            # Only create config file if it doesn't exist (to preserve UUID after registration)
            if [ ! -f ${cfg.dataDir}/config.json ]; then
              # First time setup - create config from template
              cp ${agentConfig} ${cfg.dataDir}/config.json
              chown ${cfg.user}:${cfg.group} ${cfg.dataDir}/config.json
              chmod 640 ${cfg.dataDir}/config.json
            fi

            # Don't link hashcat here - do it in ExecStartPost after agent starts
          '';
        in "+${preStartScript}";

        ExecStart = "${cfg.package}/bin/hashtopolis-agent";

        # Run after agent starts to set up hashcat
        ExecStartPost = let
          postStartScript = pkgs.writeShellScript "hashtopolis-agent-poststart" ''
            # Wait a moment for agent to initialize
            sleep 5

            # Create wrapper scripts for downloaded hashcat binaries
            # The server downloads hashcat.bin but expects to run ./hashcat
            for dir in ${cfg.crackersPath}/*/; do
              if [ -d "$dir" ] && [ -f "$dir/hashcat.bin" ] && [ ! -f "$dir/hashcat" ]; then
                # Create a wrapper that runs hashcat.bin with proper LD setup
                cat > "$dir/hashcat" <<'EOF'
            #!/bin/sh
            exec "$(dirname "$0")/hashcat.bin" "$@"
            EOF
                chmod +x "$dir/hashcat"
                chown ${cfg.user}:${cfg.group} "$dir/hashcat"
              fi
            done

            # Link native hashcat if configured
            ${optionalString (cfg.useNativeHashcat && cfg.hashcatPackage != null) ''
              if [ ! -f ${cfg.crackersPath}/hashcat ]; then
                ln -sf ${cfg.hashcatPackage}/bin/hashcat ${cfg.crackersPath}/hashcat
                chown -h ${cfg.user}:${cfg.group} ${cfg.crackersPath}/hashcat
              fi
            ''}
          '';
        in "+${postStartScript}";

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
        SupplementaryGroups = mkIf (elem "gpu" cfg.deviceTypes) [ "video" "render" ];

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