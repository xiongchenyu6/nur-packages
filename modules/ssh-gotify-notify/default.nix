# Edit this configuration file to define what should be installed on

# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ pkgs, config, lib, ... }:
with lib;
let
  file-path = builtins.split "/" (toString ./.);
  serviceName = lib.last file-path;
  cfg = config.services.ssh-gotify-notify;
in {
  options = {
    services = {
      "${serviceName}" = {
        enable = mkEnableOption "Enables ${serviceName} service";
        url = mkOption {
          description = lib.mdDoc "url";
          default = "https://gotify.inner.trontech.link";
          type = types.str;
        };
        token = mkOption {
          description = lib.mdDoc "token";
          type = types.str;
        };
        check-break-seconds = mkOption {
          description = lib.mdDoc "check-break-seconds";
          default = 5;
          type = types.int;
        };
      };
    };
  };
  config = {
    systemd = {
      services = mkIf cfg.enable {
        "${serviceName}" = {
          path = with pkgs; [ gawk curl inetutils ];
          script = ''
            #!/usr/bin/env bash

            notify() {
                    now=$(date -d "-60 seconds" +%s)
                    end=$((SECONDS+30))

                    while [ $SECONDS -lt $end ]; do

                            SSHdate=$(date -d "$(who |grep pts|tail -1 | awk '{print $3, $4}')" +%s)

                            if [ $SSHdate -ge $now ]; then

                                    title="SSH Login for $(hostname -f)"
                                    message="$(who | grep pts)"

                                    curl -X POST -s \
                                            -F "title=''${title}" \
                                            -F "message=''${message}" \
                                            -F "priority=5" \
                                            "${cfg.url}/message?token=${cfg.token}"
                             fi
                             sleep ${toString cfg.check-break-seconds}
                    done
            }

            notify
          '';

        };
      };
    };
  };
}
