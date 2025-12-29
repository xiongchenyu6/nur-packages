{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.hashtopolis-agent;

  hashtopolisAgentPkg = pkgs.callPackage ../../pkgs/hashtopolis-agent/package.nix { };

  gpuEnabled = elem "gpu" cfg.deviceTypes;
  cpuEnabled = elem "cpu" cfg.deviceTypes;

  # Resolve hashcat package: use configured package, or default to appropriate hashcat when useNativeHashcat is true
  effectiveHashcatPackage = if cfg.hashcatPackage != null then cfg.hashcatPackage
                            else if cfg.useNativeHashcat then (if gpuEnabled then (pkgs.hashcat.override { cudaSupport = true; }) else pkgs.hashcat)
                            else null;

  # Get hashcat binary - always use the wrapper which sets up LD_LIBRARY_PATH for CUDA
  hashcatBinary = if effectiveHashcatPackage != null
                  then "${effectiveHashcatPackage}/bin/hashcat"
                  else null;

  # Helper to check if a path is under another path
  isSubPath = parent: child: lib.hasPrefix (toString parent) (toString child);

  # Get extra paths that need write access (paths not under dataDir)
  extraWritePaths = lib.filter (p: !isSubPath cfg.dataDir p) [
    cfg.crackersPath
    cfg.princePath
    cfg.preprocessorsPath
  ];

  openclLibs = with pkgs; [
    ocl-icd
    zlib
    ncurses5
    stdenv.cc.cc.lib
  ] ++ optionals gpuEnabled [
    cudatoolkit
    linuxPackages.nvidia_x11
    libGLU
    libGL
    xorg.libXi
    xorg.libXmu
    freeglut
    xorg.libXext
    xorg.libX11
    xorg.libXv
    xorg.libXrandr
  ] ++ optionals (cpuEnabled && !gpuEnabled) [
    pocl
  ];

  # Base configuration template (without voucher)
  agentConfigTemplate = {
    url = cfg.serverUrl;
    uuid = cfg.uuid;
    "files-path" = "${cfg.dataDir}/files";
    "hashlist-path" = "${cfg.dataDir}/hashlists";
    "zaps-path" = "${cfg.dataDir}/zaps";
    "crackers-path" = cfg.crackersPath;
    "prince-path" = cfg.princePath;
    "preprocessors-path" = cfg.preprocessorsPath;
    "use-native-hashcat" = cfg.useNativeHashcat;
    "allow-piping" = cfg.allowPiping;
    "disable-update" = true;
  };

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

    voucherFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/hashtopolis-voucher";
      description = "Path to file containing voucher token (e.g., SOPS secret). Takes precedence over voucher option.";
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
      description = "Hashcat package to use when useNativeHashcat is true. Defaults to pkgs.hashcat when useNativeHashcat is enabled and this is not set.";
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
        ocl-icd
      ] ++ openclLibs ++ optionals gpuEnabled [
        linuxPackages.nvidia_x11
      ];
    };

    # Create user and group
    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
      extraGroups = [ "video" "render" ]; # For GPU access
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
      after = [ "network-online.target" "systemd-tmpfiles-setup.service" ];
      wants = [ "network-online.target" ];
      requires = [ "systemd-tmpfiles-setup.service" ];

      environment = {
        HOME = cfg.dataDir;
        # Point to the config file in the data directory
        HASHTOPOLIS_CONFIG = "${cfg.dataDir}/config.json";
      } // optionalAttrs (cfg.cpuOnly) {
        CUDA_VISIBLE_DEVICES = "-1"; # Disable CUDA
      } // optionalAttrs (cfg.gpuDevices != []) {
        CUDA_VISIBLE_DEVICES = concatStringsSep "," (map toString cfg.gpuDevices);
      } // optionalAttrs gpuEnabled {
        CUDA_PATH = "${pkgs.cudatoolkit}";
        # Set a writable cache path for the CUDA JIT compiler
        CUDA_CACHE_PATH = "${cfg.dataDir}/.nv";
        EXTRA_LDFLAGS = "-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib";
        EXTRA_CCFLAGS = "-I/usr/include";
        # Note: LD_LIBRARY_PATH is NOT set here because the hashcat wrapper script
        # already handles library paths correctly. Setting it here would interfere.
      };

      path = with pkgs; [
        pciutils  # lspci for hardware detection
        p7zip     # 7z/7zr for extracting archives
        unzip
        gnumake
        binutils
        stdenv.cc
      ] ++ optionals (elem "gpu" cfg.deviceTypes) [
        cudatoolkit
        ocl-icd
      ] ++ optionals (cfg.useNativeHashcat && effectiveHashcatPackage != null) [
        effectiveHashcatPackage
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
              echo "Creating initial config file..."

              # Read voucher from file if specified, otherwise use direct value
              VOUCHER="${cfg.voucher}"
              ${optionalString (cfg.voucherFile != null) ''
                if [ -f "${cfg.voucherFile}" ]; then
                  VOUCHER=$(cat "${cfg.voucherFile}" | tr -d '\n')
                  echo "Loaded voucher from file: ${cfg.voucherFile}"
                else
                  echo "Warning: Voucher file ${cfg.voucherFile} not found, using direct voucher value"
                fi
              ''}

              # Create config JSON
              cat > ${cfg.dataDir}/config.json <<EOF
            {
              "url": "${cfg.serverUrl}",
              "voucher": "$VOUCHER",
              "uuid": "${cfg.uuid}",
              "files-path": "${cfg.dataDir}/files",
              "hashlist-path": "${cfg.dataDir}/hashlists",
              "zaps-path": "${cfg.dataDir}/zaps",
              "crackers-path": "${cfg.crackersPath}",
              "prince-path": "${cfg.princePath}",
              "preprocessors-path": "${cfg.preprocessorsPath}",
              "use-native-hashcat": ${if cfg.useNativeHashcat then "true" else "false"},${optionalString (cfg.useNativeHashcat && hashcatBinary != null) ''
              "native-hashcat-path": "${hashcatBinary}",''}
              "allow-piping": ${if cfg.allowPiping then "true" else "false"},
              "disable-update": true
            }
            EOF

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
            ${optionalString (cfg.useNativeHashcat && hashcatBinary != null) ''
              if [ ! -f ${cfg.crackersPath}/hashcat ]; then
                ln -sf ${hashcatBinary} ${cfg.crackersPath}/hashcat
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

        # Security hardening has been removed.
      };
    };

    # Install hashcat if requested
    environment.systemPackages = mkIf (cfg.useNativeHashcat && effectiveHashcatPackage != null) [
      effectiveHashcatPackage
    ];

    # GPU support - ensure necessary drivers are available
    hardware.graphics = mkIf (elem "gpu" cfg.deviceTypes) {
      enable = true;
    };
  };
}
