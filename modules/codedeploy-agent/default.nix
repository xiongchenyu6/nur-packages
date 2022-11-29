# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  file-path = builtins.split "/" (toString ./.);
  serviceName = lib.last file-path;
  cfg = config.services.${serviceName};
  configFile = pkgs.writeText "${serviceName}.yml" ''
    ---
    :log_aws_wire: false
    :log_dir: '~/log'
    :pid_dir: '~'
    :program_name: codedeploy-agent
    :root_dir: '~/deployment-root'
    :verbose: true
    :wait_between_runs: 1
    :proxy_uri:
    :max_revisions: 5
  '';
in {
  options = {
    services = {
      "${serviceName}" = {
        enable = mkEnableOption "Enables ${serviceName} service";
      };
    };
  };
  config = {
    systemd = {
      services = mkIf cfg.enable {
        "${serviceName}" = {
          wantedBy = ["multi-user.target"];
          after = ["networking.target"];
          startLimitIntervalSec = 500;
          startLimitBurst = 5;
          environment = {};
          preStart = "";
          script = "${pkgs.codedeploy-agent}/bin/codedeploy-agent --config_file=${configFile} start";
          postStart = "";
          onSuccess = [];
          onFailure = [];
          serviceConfig = {
            User = serviceName;
            Restart = "on-failure";
            RestartSec = "5s";
            WorkingDirectory = "/var/lib/${serviceName}";
            StateDirectory = serviceName;
            RuntimeDirectory = serviceName;
            LogsDirectory = serviceName;
            CacheDirectory = serviceName;
            Type = "forking";
            PIDFile = "/var/lib/${serviceName}/${serviceName}.pid";
          };
        };
      };
    };

    users.users."${serviceName}" = {
      description = "${serviceName} user";
      isSystemUser = true;
      group = serviceName;
      createHome = true;
      home = "/var/lib/${serviceName}";
    };
    users.groups."${serviceName}" = {};
  };
}
