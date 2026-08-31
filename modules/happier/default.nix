{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.happier;

  happierPkg = pkgs.callPackage ../../pkgs/happier-cli/package.nix { };
in
{
  options.services.happier = {
    enable = mkEnableOption "Happier daemon (mobile/web control for local AI coding sessions)";

    package = mkOption {
      type = types.package;
      default = happierPkg;
      defaultText = literalExpression "pkgs.happier-cli";
      description = "The happier-cli package to run.";
    };

    users = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "alice" ];
      description = ''
        为哪些用户启用 daemon 的 user service。

        daemon 必须跑在**用户**下而不是 root:它读写 `~/.happier`(relay 配置和
        凭据)、并且要以该用户的身份 fork 出 codex / claude 会话。列表为空时
        只装 CLI,不起任何服务。

        每个用户仍需自己跑一次 `happier auth login` 完成配对 —— 凭据是端到端
        加密的一部分,不能从配置里声明。
      '';
    };

    environmentFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      example = "/run/secrets/happier.env";
      description = ''
        传给 daemon 的 EnvironmentFile,daemon fork 出来的会话会继承它。

        典型用途是 `OPENAI_API_KEY` —— happier 起 codex 时**不会**自己去读
        `~/.codex/auth.json`,不给的话会话起得来、手机也看得到,但一发消息就
        没反应。文件形式而不是 nix 选项,是为了让密钥不进 nix store。
      '';
    };

    extraEnvironment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = literalExpression ''{ HAPPIER_CODEX_BACKEND_MODE = "mcp"; }'';
      description = ''
        追加给 daemon 的环境变量(非密钥)。

        `HAPPIER_CODEX_BACKEND_MODE` 可选 `appServer`(默认,终端有 codex TUI)
        或 `mcp`(没有 TUI、纯远程)。
      '';
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    systemd.user.services.happier-daemon = {
      description = "Happier daemon";
      documentation = [ "https://happier.dev" ];

      # 只在列出的用户下启动。systemd 的 user unit 本身对所有用户可见,
      # 用 ConditionUser 挡住其余的 —— 没配过 ~/.happier 的用户跑起来只会
      # 空转报错。
      unitConfig.ConditionUser = cfg.users;

      wantedBy = [ "default.target" ];
      after = [ "network-online.target" ];

      environment = {
        # 上游默认往自己的 Sentry 报错误,自建实例不需要。
        HAPPIER_SENTRY_USE_CENTRAL_DSN = "0";
      }
      // cfg.extraEnvironment;

      serviceConfig = {
        Type = "simple";
        # `start-sync` 才是前台常驻的那个;`daemon start` 会 detach,
        # systemd 会当它退出了然后反复重启。
        ExecStart = "${getExe cfg.package} daemon start-sync";
        Restart = "on-failure";
        RestartSec = 5;
      }
      // optionalAttrs (cfg.environmentFile != null) {
        EnvironmentFile = cfg.environmentFile;
      };

      # daemon 要 fork codex/claude/git,这些得在 PATH 里。
      path = [
        pkgs.git
        pkgs.openssh
      ];
    };
  };
}
