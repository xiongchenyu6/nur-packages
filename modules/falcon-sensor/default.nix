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
    # Create required directories with proper permissions
    mkdir -p /opt/CrowdStrike
    mkdir -p /var/log/crowdstrike
    chmod 755 /var/log/crowdstrike

    # Link necessary files
    ln -sf ${falcon}/opt/CrowdStrike/* /opt/CrowdStrike

    # Set CID from file if provided
    ${optionalString (cfg.cidFile != null) ''
      CID=$(cat ${cfg.cidFile})
      if [ -n "$CID" ]; then
        ${falcon}/bin/fs-bash -c "${falcon}/opt/CrowdStrike/falconctl -s --cid=$CID"
      else
        echo "Error: CID file is empty or unreadable"
        exit 1
      fi
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
