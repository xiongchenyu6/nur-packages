{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.services.agents-server;

  isLoopbackBind = elem cfg.bind [
    "127.0.0.1"
    "localhost"
    "::1"
  ];
in
{
  options.services.agents-server = {
    enable = mkEnableOption "AgentsServer, the self-hosted execution backend for AgentsDock";

    package = mkOption {
      type = types.package;
      default = pkgs.callPackage ../../pkgs/agents-server/package.nix { };
      defaultText = literalExpression "pkgs.callPackage ../../pkgs/agents-server/package.nix { }";
      description = "The agents-server package to run.";
    };

    bind = mkOption {
      type = types.str;
      default = "127.0.0.1";
      example = "0.0.0.0";
      description = ''
        Address the server listens on. Keep this on loopback and reach it over
        Tailscale or an authenticating reverse proxy; exposing it directly
        hands remote callers shell-equivalent access to the agent's workspaces.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 7850;
      description = "Port for the AgentsServer HTTP/WebSocket API.";
    };

    backend = mkOption {
      type = types.enum [
        "claude"
        "codex"
      ];
      default = "claude";
      description = "Default agent backend used for new chats.";
    };

    stateDir = mkOption {
      type = types.str;
      default = "/var/lib/agents-server";
      description = ''
        Directory holding chat state, uploads, and event history. Also serves
        as the service user's HOME, so the Claude and Codex CLIs store their
        credentials underneath it.
      '';
    };

    agentCwd = mkOption {
      type = types.str;
      default = cfg.stateDir;
      defaultText = literalExpression "config.services.agents-server.stateDir";
      description = "Default working directory agents are started in.";
    };

    tokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/agents-server-token";
      description = ''
        Path to a file containing the bearer token clients must present. The
        file is read at service start via systemd credentials, so the token
        never lands in the Nix store or in unit environment listings.

        Leaving this null disables authentication entirely and is therefore
        only permitted on a loopback bind.
      '';
    };

    tls = {
      certFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to a TLS certificate file. Enables HTTPS when set together with keyFile.";
      };

      keyFile = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "Path to the TLS private key file matching certFile.";
      };
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "[ pkgs.claude-code pkgs.codex pkgs.nodejs ]";
      description = ''
        Extra packages placed on the service PATH. The Claude and Codex CLIs
        are not runtime dependencies of the package because they need per-user
        credentials, so wire whichever backend you use in here.
      '';
    };

    environment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = {
        AGENTSDOCK_WORKSPACE_TEXT_MAX_BYTES = "2000000";
      };
      description = "Additional AGENTSDOCK_* environment variables passed to the service.";
    };

    environmentFiles = mkOption {
      type = types.listOf types.path;
      default = [ ];
      example = [ "/run/secrets/agents-server.env" ];
      description = "systemd EnvironmentFile entries for provider API keys or proxy settings.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the configured port in the firewall.";
    };

    user = mkOption {
      type = types.str;
      default = "agents-server";
      description = "User to run AgentsServer as.";
    };

    group = mkOption {
      type = types.str;
      default = "agents-server";
      description = "Group to run AgentsServer as.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.tokenFile != null || isLoopbackBind;
        message = ''
          services.agents-server: binding to ${cfg.bind} without a tokenFile
          leaves the API unauthenticated, and it can spawn agents with full
          access to the workspaces. Set services.agents-server.tokenFile, or
          bind to 127.0.0.1 and front it with Tailscale or a reverse proxy.
        '';
      }
      {
        assertion = (cfg.tls.certFile == null) == (cfg.tls.keyFile == null);
        message = "services.agents-server: tls.certFile and tls.keyFile must be set together.";
      }
    ];

    systemd.services.agents-server = {
      description = "AgentsServer execution backend for AgentsDock";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      path = cfg.extraPackages;

      environment = {
        AGENTSDOCK_STATE_DIR = cfg.stateDir;
        AGENTSDOCK_AGENT_CWD = cfg.agentCwd;
        AGENTSDOCK_BACKEND = cfg.backend;
        HOME = cfg.stateDir;
      }
      // optionalAttrs (cfg.tls.certFile != null) {
        AGENTSDOCK_AGENT_TLS_CERTFILE = toString cfg.tls.certFile;
        AGENTSDOCK_AGENT_TLS_KEYFILE = toString cfg.tls.keyFile;
      }
      // cfg.environment;

      script = ''
        ${optionalString (cfg.tokenFile != null) ''
          # Command substitution strips the trailing newline secret files
          # usually carry; the server compares tokens with hmac.compare_digest
          # and would otherwise reject every client. An empty token silently
          # disables authentication server-side, so refuse to start instead.
          AGENTSDOCK_AGENT_TOKEN="$(< "$CREDENTIALS_DIRECTORY/token")"
          if [ -z "$AGENTSDOCK_AGENT_TOKEN" ]; then
            echo "agents-server: ${toString cfg.tokenFile} is empty; refusing to start unauthenticated" >&2
            exit 1
          fi
          export AGENTSDOCK_AGENT_TOKEN
        ''}
        exec ${getExe cfg.package} serve \
          --bind ${escapeShellArg cfg.bind} \
          --port ${toString cfg.port}
      '';

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.stateDir;
        Restart = "always";
        RestartSec = "5s";

        LoadCredential = optional (cfg.tokenFile != null) "token:${toString cfg.tokenFile}";

        EnvironmentFile = cfg.environmentFiles;

        StateDirectory = mkIf (cfg.stateDir == "/var/lib/agents-server") "agents-server";
        StateDirectoryMode = "0700";

        # Deliberately light on sandboxing: the whole point of the service is to
        # run Claude Code and Codex against the user's workspaces, so filesystem
        # and exec restrictions would break the agents it supervises.
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectControlGroups = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        RestrictSUIDSGID = true;
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.port ];

    users.users.${cfg.user} = mkIf (cfg.user == "agents-server") {
      description = "AgentsServer service user";
      isSystemUser = true;
      inherit (cfg) group;
      home = cfg.stateDir;
    };

    users.groups.${cfg.group} = mkIf (cfg.group == "agents-server") { };
  };
}
