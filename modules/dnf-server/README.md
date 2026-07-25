# DNF Server Module

This module deploys a private [Dungeon & Fighter](https://en.wikipedia.org/wiki/Dungeon_Fighter_Online) (DNF / 地下城与勇士) game server using the [`1995chen/dnf`](https://github.com/1995chen/dnf) and `1995chen/mysql` container images.

It exposes the option `services.dnf-server-native` and orchestrates two OCI containers (`mysql` and `dnf-1`) under either Docker or Podman.

## Basic Usage

```nix
{ config, ... }:

{
  imports = [ inputs.xiongchenyu6.nixosModules.dnf-server ];

  sops.secrets."dnf/root_password" = { };
  sops.secrets."dnf/gm_password" = { };
  sops.secrets."dnf/gm_connect_key" = { };
  sops.secrets."dnf/game_password" = { };

  services.dnf-server-native = {
    enable = true;
    publicIP = "192.168.15.210";       # IP clients will connect to
    backend = "podman";                # or "docker"
    rootPasswordFile = config.sops.secrets."dnf/root_password".path;
    gmPasswordFile = config.sops.secrets."dnf/gm_password".path;
    gmConnectKeyFile = config.sops.secrets."dnf/gm_connect_key".path;
    gamePasswordFile = config.sops.secrets."dnf/game_password".path;
    serverGroup = 3;                   # 3 = siroco
    serverGroupDB = "cain";            # see "Quirks" below
    openChannels = "11,52";
  };
}
```

The container backend (`docker` or `podman`) must be enabled separately via `virtualisation.docker.enable` / `virtualisation.podman.enable`.

## Architecture

The module runs two containers on a private bridge network `dnf-net` (10.90.0.0/24):

| Container | Image                            | IP          | Role                                  |
|-----------|----------------------------------|-------------|---------------------------------------|
| `mysql`   | `docker.io/1995chen/mysql:7-5.0.95` | `10.90.0.10` | MySQL 5.0.95 game database (port 4000) |
| `dnf-1`   | `docker.io/1995chen/dnf:centos7-latest` | `10.90.0.20` | Game server (supervisor, df_game_r, channel, bridge, …) |

This differs from the upstream `1995chen/dnf` quick-start, which packs MySQL inside the same container. Splitting them out lets you scale or back up the database independently and lifts the server's memory limit cleanly.

Persistent state lives under `dataDir` (default `/var/lib/dnf-server`):

```
/var/lib/dnf-server/
├── mysql/   # MySQL datadir (bind-mounted into mysql container)
├── data/    # PVF, keys, runtime data (bind-mounted into dnf-1)
└── log/     # Per-channel game logs (bind-mounted into dnf-1)
```

## Quirks

### `gamePassword` must be exactly 8 characters

The `1995chen/dnf` image hard-codes the length of the in-game `game` MySQL user's password. The module asserts this and refuses to start otherwise:

```
ERROR: gamePassword must be exactly 8 chars, got N
```

### `serverGroupDB = "cain"` even for non-cain server groups

Upstream's GM tools assume the server-group database is named `cain` regardless of `SERVER_GROUP`. Leave `serverGroupDB = "cain"` unless you know exactly what you are doing, or the GM lander will fail to connect to the channel DB.

### MySQL is exposed on host port 3000, not 3306

The upstream image listens on container port 4000; the module maps it to host port 3000. Connect with:

```
mysql -h 127.0.0.1 -P 3000 -u root -p
```

The `game` user is restricted to the container's IP (`10.90.0.20`) and cannot connect from the host — use `root` for external access.

### Harmless `Failed to get D-Bus connection` in journald

The MySQL container's entrypoint calls `service mysql start`. The sysvinit `service` wrapper tries D-Bus first (which doesn't exist inside the container), prints `Failed to get D-Bus connection: Operation not permitted` to stderr, then transparently falls back to `/etc/init.d/mysql start`. MySQL still comes up — you'll see `Starting MySQL. SUCCESS!` immediately after. This is a cosmetic message from the wrapper, not a service failure, and cannot be suppressed without rebuilding the upstream image.

If it really bothers you, drop a journald log filter into the unit:

```nix
systemd.services.podman-mysql.serviceConfig.LogFilterPatterns =
  [ "~Failed to get D-Bus connection" ];
```

(Use `docker-mysql` if your backend is docker.)

### Restart command

Restart both containers in the right order:

```
systemctl restart podman-mysql && systemctl restart podman-dnf-1
```

The systemd dependencies (`requires = create-dnf-network create-dnf-env mysql`) handle ordering automatically on boot.

## Open Ports

The module opens the firewall for:

| Port            | Proto    | Purpose                |
|-----------------|----------|------------------------|
| 2000            | TCP      | Supervisor web UI      |
| `mysqlPort`     | TCP      | MySQL (default 3000)   |
| 7600            | TCP      | 统一登陆器 (launcher)  |
| 881             | TCP      | 统一网关 (gateway)     |
| 7001            | TCP/UDP  | `df_channel_r`         |
| 7300            | TCP/UDP  | `df_relay_r`           |
| 30011 / 31011   | TCP / UDP | `df_game_r` (ch.11)   |
| 30052 / 31052   | TCP / UDP | `df_game_r` (ch.52)   |
| 2311–2313       | UDP      | `df_stun_r`            |

## Default Gateway Credentials

Per upstream README:

```
Gateway port:      881
Comm key:          763WXRBW3PFTC3IXPFWH
Launcher version:  20180307   (must match GM lander)
Launcher port:     7600
GM account:        gmuser
```

## References

- Upstream image / docs: <https://github.com/1995chen/dnf>
- 2.1.7 port migration notes: see upstream README "2.1.7 版本升级注意事项"
- Architecture diagram: <https://github.com/1995chen/dnf/blob/main/doc/ArchitectureDiagram.md>
