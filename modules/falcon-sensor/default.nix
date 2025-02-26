{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.falcon-sensor;
  falcon = pkgs.falcon-sensor;

  startPreScript = pkgs.writeScript "init-falcon" ''
    #! ${pkgs.bash}/bin/sh
    set -e

    # Create required directories with proper permissions
    mkdir -p /opt/CrowdStrike
    mkdir -p /var/log/crowdstrike
    chmod 755 /var/log/crowdstrike

    # Create the falconctl.log file with proper permissions and ensure it's writable
    touch /var/log/falconctl.log || true
    chmod 666 /var/log/falconctl.log || true

    # Clear and recreate the directory to avoid linking errors
    rm -rf /opt/CrowdStrike/* 2>/dev/null || true

    # Link necessary files one by one to handle directories properly
    for file in ${falcon}/opt/CrowdStrike/*; do
      base=$(basename "$file")
      ln -sfn "$file" "/opt/CrowdStrike/$base"
    done

    # Set CID from file if provided
    ${optionalString (cfg.cidFile != null) ''
      CID=$(cat ${cfg.cidFile})
      if [ -n "$CID" ]; then
        # Add the -f flag which is required when setting CID
        ${falcon}/bin/fs-bash -c "${falcon}/opt/CrowdStrike/falconctl -s -f --cid=$CID"
      else
        echo "Error: CID file is empty or unreadable"
        exit 1
      fi
    ''}

    # Set trace level if specified
    ${optionalString (cfg.traceLevel != null) ''
      echo "Setting Falcon trace level to: ${cfg.traceLevel}"
      # Correct format for setting trace level
      ${falcon}/bin/fs-bash -c "${falcon}/opt/CrowdStrike/falconctl -s -f --trace=${cfg.traceLevel}"
    ''}
  '';
in
{
  options.services.falcon-sensor = {
    enable = mkEnableOption "CrowdStrike Falcon Sensor";

    cidFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to a file containing the CrowdStrike Customer ID (CID).
        This can be an encrypted file managed by SOPS.
      '';
      example = "/run/secrets/falcon-cid";
    };

    traceLevel = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Sets the trace level for the Falcon Sensor.
        Valid values include: none, err, warn, info, debug

        Note: This must be specified as a parameter with equals sign, 
        e.g., --trace=debug (not as a separate argument).
      '';
      example = "debug";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.falcon-sensor = {
      enable = true;
      description = "CrowdStrike Falcon Sensor";
      unitConfig.DefaultDependencies = false;
      after = [ "local-fs.target" ];
      conflicts = [ "shutdown.target" ];
      before = [
        "sysinit.target"
        "shutdown.target"
      ];
      serviceConfig = {
        ExecStartPre = "${startPreScript}";
        ExecStart = "${falcon}/bin/fs-bash -c \"${falcon}/opt/CrowdStrike/falcond\"";
        Type = "forking";
        PIDFile = "/run/falcond.pid";
        Restart = "on-failure";
        RestartSec = "10s";
        TimeoutStopSec = "60s";
        KillMode = "process";
        RuntimeDirectory = "crowdstrike";
        RuntimeDirectoryMode = "0755";
        StateDirectory = "crowdstrike";
        StateDirectoryMode = "0755";
        LogsDirectory = "crowdstrike";
        LogsDirectoryMode = "0755";
      };
      wantedBy = [ "multi-user.target" ];
    };
  };
}
