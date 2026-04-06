{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.cc-gateway;

  ccGatewayPkg = pkgs.callPackage ../../pkgs/cc-gateway/package.nix { };

  generatedConfig = pkgs.writeText "cc-gateway-config-base.json" (
    builtins.toJSON {
      server = {
        port = cfg.port;
      }
      // optionalAttrs cfg.tls.enable {
        tls = {
          cert = cfg.tls.certFile;
          key = cfg.tls.keyFile;
        };
      };

      upstream = {
        url = cfg.upstreamUrl;
      };

      identity = {
        device_id = cfg.identity.deviceId;
        email = cfg.identity.email;
      };

      env = cfg.env;
      prompt_env = cfg.promptEnv;
      process = cfg.process;
      logging = {
        level = cfg.logging.level;
        audit = cfg.logging.audit;
      };
    }
  );
in
{
  options.services.cc-gateway = {
    enable = mkEnableOption "cc-gateway service";

    package = mkOption {
      type = types.package;
      default = ccGatewayPkg;
      description = "cc-gateway package to use.";
    };

    user = mkOption {
      type = types.str;
      default = "cc-gateway";
      description = "User under which cc-gateway runs.";
    };

    group = mkOption {
      type = types.str;
      default = "cc-gateway";
      description = "Group under which cc-gateway runs.";
    };

    dataDir = mkOption {
      type = types.str;
      default = "/var/lib/cc-gateway";
      description = "State directory for cc-gateway.";
    };

    port = mkOption {
      type = types.port;
      default = 8443;
      description = "Port that cc-gateway listens on.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the configured port in the firewall.";
    };

    environmentFiles = mkOption {
      type = types.listOf (types.either types.path types.str);
      default = [ ];
      example = [ "/run/keys/cc-gateway.env" ];
      description = "Optional systemd EnvironmentFile entries for proxy variables or other runtime environment.";
    };

    configFile = mkOption {
      type = types.nullOr (types.either types.path types.str);
      default = null;
      description = "Existing config.yaml path to use instead of generating one at service start.";
    };

    refreshTokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a file containing the Anthropic OAuth refresh token. Required unless configFile is set.";
    };

    accessTokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional path to a file containing the Anthropic OAuth access token.";
    };

    clientTokensFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to a JSON file containing the auth.tokens array. Required unless configFile is set.";
    };

    upstreamUrl = mkOption {
      type = types.str;
      default = "https://api.anthropic.com";
      description = "Upstream Anthropic API URL.";
    };

    identity = {
      deviceId = mkOption {
        type = types.str;
        description = "Device ID presented by the gateway. Must not contain the upstream placeholder value.";
      };

      email = mkOption {
        type = types.str;
        description = "Email presented by the gateway.";
      };
    };

    tls = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Whether to enable TLS in the generated config.";
      };

      certFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the TLS certificate file.";
      };

      keyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the TLS private key file.";
      };
    };

    env = mkOption {
      type = types.attrs;
      default = {
        platform = "linux";
        platform_raw = "linux";
        arch = "x64";
        node_version = "v22.0.0";
        terminal = "xterm-256color";
        package_managers = "npm";
        runtimes = "node";
        is_running_with_bun = false;
        is_ci = false;
        is_claude_ai_auth = true;
        version = "2.1.81";
        version_base = "2.1.81";
        build_time = "2026-03-20T21:26:18Z";
        deployment_environment = "nixos";
        vcs = "git";
      };
      description = "Non-secret env section written to the generated config.";
    };

    promptEnv = mkOption {
      type = types.attrs;
      default = {
        platform = "linux";
        shell = "bash";
        os_version = "NixOS";
        working_dir = "/var/lib/cc-gateway";
      };
      description = "Non-secret prompt_env section written to the generated config.";
    };

    process = mkOption {
      type = types.attrs;
      default = {
        constrained_memory = 34359738368;
        rss_range = [
          300000000
          500000000
        ];
        heap_total_range = [
          40000000
          80000000
        ];
        heap_used_range = [
          100000000
          200000000
        ];
      };
      description = "Non-secret process section written to the generated config.";
    };

    logging = {
      level = mkOption {
        type = types.str;
        default = "info";
        description = "Logging level.";
      };

      audit = mkOption {
        type = types.bool;
        default = true;
        description = "Whether to enable audit logging.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.configFile != null || cfg.refreshTokenFile != null;
        message = "services.cc-gateway.refreshTokenFile is required when services.cc-gateway.configFile is not set.";
      }
      {
        assertion = cfg.configFile != null || cfg.clientTokensFile != null;
        message = "services.cc-gateway.clientTokensFile is required when services.cc-gateway.configFile is not set.";
      }
      {
        assertion = !cfg.tls.enable || (cfg.tls.certFile != null && cfg.tls.keyFile != null);
        message = "services.cc-gateway.tls.certFile and services.cc-gateway.tls.keyFile must be set when TLS is enabled.";
      }
    ];

    users.users.${cfg.user} = {
      isSystemUser = true;
      group = cfg.group;
      home = cfg.dataDir;
      createHome = true;
    };

    users.groups.${cfg.group} = { };

    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 ${cfg.user} ${cfg.group} -"
    ];

    networking.firewall.allowedTCPPorts = optional cfg.openFirewall cfg.port;

    systemd.services.cc-gateway = {
      description = "cc-gateway";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        HOME = cfg.dataDir;
      };

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.dataDir;
        StateDirectory = "cc-gateway";
        StateDirectoryMode = "0750";
        ExecStartPre =
          if cfg.configFile != null then
            "${pkgs.coreutils}/bin/install -m 600 -o ${cfg.user} -g ${cfg.group} ${escapeShellArg (toString cfg.configFile)} ${cfg.dataDir}/config.yaml"
          else
            (pkgs.writeShellScript "cc-gateway-pre-start" ''
              set -euo pipefail
              export BASE_CONFIG=${escapeShellArg (toString generatedConfig)}
              export CONFIG_PATH=${escapeShellArg "${cfg.dataDir}/config.yaml"}
              export REFRESH_TOKEN_FILE=${escapeShellArg (toString cfg.refreshTokenFile)}
              export CLIENT_TOKENS_FILE=${escapeShellArg (toString cfg.clientTokensFile)}
              export ACCESS_TOKEN_FILE=${
                escapeShellArg (if cfg.accessTokenFile == null then "" else toString cfg.accessTokenFile)
              }

              ${pkgs.nodejs_22}/bin/node <<'EOF'
              const fs = require('fs');

              const baseConfig = JSON.parse(fs.readFileSync(process.env.BASE_CONFIG, 'utf8'));
              const refreshToken = fs.readFileSync(process.env.REFRESH_TOKEN_FILE, 'utf8').trim();
              const clientTokens = JSON.parse(fs.readFileSync(process.env.CLIENT_TOKENS_FILE, 'utf8'));
              const accessToken = process.env.ACCESS_TOKEN_FILE
                ? fs.readFileSync(process.env.ACCESS_TOKEN_FILE, 'utf8').trim()
                : null;

              const config = {
                ...baseConfig,
                oauth: {
                  refresh_token: refreshToken,
                  ...(accessToken ? { access_token: accessToken } : {}),
                },
                auth: {
                  tokens: clientTokens,
                },
              };

              fs.writeFileSync(process.env.CONFIG_PATH, JSON.stringify(config, null, 2));
              EOF

              chown ${cfg.user}:${cfg.group} ${cfg.dataDir}/config.yaml
              chmod 600 ${cfg.dataDir}/config.yaml
            '');
        ExecStart = "${cfg.package}/bin/cc-gateway ${cfg.dataDir}/config.yaml";
        Restart = "on-failure";
        RestartSec = "10s";
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ cfg.dataDir ];
        PrivateTmp = true;
      }
      // optionalAttrs (cfg.environmentFiles != [ ]) {
        EnvironmentFile = cfg.environmentFiles;
      };
    };
  };
}
