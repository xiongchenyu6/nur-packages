{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.codexpro;

  codexproPkg = pkgs.callPackage ../../pkgs/codexpro/package.nix { };

  startScript = pkgs.writeShellScript "codexpro-start" ''
    set -euo pipefail
    ${optionalString (cfg.httpTokenFile != null) ''
      CODEXPRO_HTTP_TOKEN="$(cat "$CREDENTIALS_DIRECTORY/http-token")"
      export CODEXPRO_HTTP_TOKEN
    ''}
    exec ${getExe' cfg.package "codexpro-mcp-http"}
  '';
in
{
  options.services.codexpro = {
    enable = mkEnableOption "codexpro self-hosted MCP server";

    package = mkOption {
      type = types.package;
      default = codexproPkg;
      defaultText = literalExpression "pkgs.codexpro";
      description = "The codexpro package to run.";
    };

    user = mkOption {
      type = types.str;
      example = "freeman";
      description = ''
        User to run codexpro as. Because codexpro reads and writes the files in
        {option}`services.codexpro.allowedRoots`, this should normally be your
        own login user so edits are owned by you and it can reach your home
        projects. There is no default to avoid silently running as the wrong user.
      '';
    };

    group = mkOption {
      type = types.str;
      default = "users";
      description = "Group to run codexpro as.";
    };

    host = mkOption {
      type = types.str;
      default = "127.0.0.1";
      description = ''
        Address codexpro binds to. Keep it on loopback and expose it through a
        tunnel (e.g. {option}`services.cloudflared`); do not bind it to a public
        interface. Binding to a non-loopback host forces token auth on.
      '';
    };

    port = mkOption {
      type = types.port;
      default = 8787;
      description = "Local port the codexpro HTTP MCP server listens on.";
    };

    root = mkOption {
      type = types.str;
      example = "/home/freeman/code/myproject";
      description = ''
        The default workspace root (`CODEXPRO_ROOT`). The repo ChatGPT operates
        on when no other root is selected. Must be inside {option}`allowedRoots`.
      '';
    };

    allowedRoots = mkOption {
      type = types.listOf types.str;
      example = literalExpression ''[ "/home/freeman/code" "/home/freeman/work" ]'';
      description = ''
        Absolute paths to the project directories ChatGPT is allowed to read and
        edit (`CODEXPRO_ALLOWED_ROOTS`). A single codexpro instance serves all of
        them.
      '';
    };

    httpTokenFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/codexpro-http-token";
      description = ''
        Path to a file containing the bearer token (`CODEXPRO_HTTP_TOKEN`) that
        ChatGPT must present (`?codexpro_token=<token>` or Authorization header).
        Required: codexpro refuses external connections without it. The file is
        read via systemd LoadCredential, never copied into the store.
      '';
    };

    bashMode = mkOption {
      type = types.enum [
        "off"
        "safe"
        "full"
      ];
      default = "safe";
      description = "Shell command policy (`CODEXPRO_BASH_MODE`).";
    };

    writeMode = mkOption {
      type = types.enum [
        "off"
        "handoff"
        "workspace"
      ];
      default = "workspace";
      description = "File editing capability (`CODEXPRO_WRITE_MODE`).";
    };

    toolMode = mkOption {
      type = types.enum [
        "minimal"
        "standard"
        "full"
      ];
      default = "standard";
      description = "Available tool set (`CODEXPRO_TOOL_MODE`).";
    };

    extraPackages = mkOption {
      type = types.listOf types.package;
      default = [ ];
      example = literalExpression "[ pkgs.ripgrep pkgs.nodejs ]";
      description = "Extra packages to put on the codexpro service PATH (tools ChatGPT may invoke).";
    };

    extraEnvironment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = literalExpression ''{ CODEXPRO_BLOCKED_GLOBS = "secrets/**"; }'';
      description = "Additional CODEXPRO_* environment variables (non-secret).";
    };

    environmentFiles = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "Extra systemd EnvironmentFile entries for additional secrets.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.allowedRoots != [ ];
        message = "services.codexpro.allowedRoots must list at least one project directory.";
      }
      {
        assertion = cfg.host == "127.0.0.1" || cfg.host == "localhost" || cfg.httpTokenFile != null;
        message = "services.codexpro.httpTokenFile is required when host is not loopback (codexpro forces token auth there).";
      }
    ];

    systemd.services.codexpro = {
      description = "codexpro self-hosted MCP server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      path = [
        pkgs.git
        pkgs.bash
        pkgs.coreutils
      ]
      ++ cfg.extraPackages;

      environment = {
        HOST = cfg.host;
        PORT = toString cfg.port;
        CODEXPRO_ROOT = cfg.root;
        CODEXPRO_ALLOWED_ROOTS = concatStringsSep "," cfg.allowedRoots;
        CODEXPRO_BASH_MODE = cfg.bashMode;
        CODEXPRO_WRITE_MODE = cfg.writeMode;
        CODEXPRO_TOOL_MODE = cfg.toolMode;
      }
      // optionalAttrs (cfg.httpTokenFile != null) {
        CODEXPRO_REQUIRE_HTTP_TOKEN = "1";
      }
      // cfg.extraEnvironment;

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = startScript;
        Restart = "on-failure";
        RestartSec = "10s";
        StateDirectory = "codexpro";
        StateDirectoryMode = "0750";
      }
      // optionalAttrs (cfg.httpTokenFile != null) {
        LoadCredential = [ "http-token:${toString cfg.httpTokenFile}" ];
      }
      // optionalAttrs (cfg.environmentFiles != [ ]) {
        EnvironmentFile = cfg.environmentFiles;
      };
    };
  };
}
