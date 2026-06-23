# codexpro module

[codexpro](https://github.com/rebel0789/codexpro) is a self-hosted MCP server
that lets ChatGPT (Developer Mode) read and edit code on **the machine codexpro
runs on**. ChatGPT lives in the cloud, so to edit your laptop's code, codexpro
must run on your laptop and a tunnel exposes its loopback port to the internet.

codexpro's own `codexpro start` launcher auto-installs `cloudflared` into
`~/.codexpro` and manages the tunnel — convenient, but impure. On NixOS this
module instead runs the plain HTTP server (`codexpro-mcp-http`) on loopback and
leaves the tunnel to nixpkgs' `services.cloudflared`, so everything is
declarative.

```
ChatGPT ──https──> Cloudflare edge ──> cloudflared (laptop) ──> codexpro :8787
                                                                    └─ reads/writes ~/code (your real files)
```

## 1. Laptop: codexpro service

```nix
{
  imports = [ inputs.nur-xiongchenyu6.nixosModules.codexpro ];

  services.codexpro = {
    enable = true;
    user = "freeman";                       # your login user, so edits are yours
    root = "/home/freeman/code/myproject";  # default workspace
    allowedRoots = [
      "/home/freeman/code"
      "/home/freeman/work"
    ];
    httpTokenFile = "/run/secrets/codexpro-http-token";
    # host defaults to 127.0.0.1, port 8787 — only cloudflared connects locally.
  };
}
```

Generate the token once (this is what ChatGPT sends as `?codexpro_token=…`):

```bash
openssl rand -hex 32 > /run/secrets/codexpro-http-token   # or manage via sops/agenix
```

## 2. Laptop: Cloudflare tunnel

A named Cloudflare tunnel gives you a stable HTTPS hostname pointing at the
loopback server. Create the tunnel once with `cloudflared tunnel login` +
`cloudflared tunnel create codexpro` (writes a credentials JSON), then:

```nix
{
  services.cloudflared = {
    enable = true;
    tunnels."<TUNNEL-UUID>" = {
      credentialsFile = "/run/secrets/cloudflared-codexpro.json";
      default = "http_status:404";
      ingress."codexpro.example.com" = "http://127.0.0.1:8787";
    };
  };
}
```

Point the DNS record at the tunnel: `cloudflared tunnel route dns codexpro codexpro.example.com`.

> Prefer no Cloudflare account? Run `codexpro start --tunnel cloudflare` manually
> for an ephemeral `trycloudflare.com` URL, or `--tunnel ngrok`. Those are
> outside this module — the module only runs the server.

## 3. Connect from ChatGPT

1. Deploy the laptop config.
2. Verify locally: `curl "http://127.0.0.1:8787/mcp?codexpro_token=$(cat /run/secrets/codexpro-http-token)"`
   should reach codexpro (an MCP response, not a connection error).
3. In ChatGPT Developer Mode, add the MCP server with URL
   `https://codexpro.example.com/mcp?codexpro_token=<your-token>`.

## Notes

- One codexpro instance serves **all** of `allowedRoots`; add a directory and
  redeploy.
- `host` stays on loopback by design — the only public surface is the
  Cloudflare tunnel, gated by the token. The module forces
  `CODEXPRO_REQUIRE_HTTP_TOKEN=1` whenever a token file is set.
- `bashMode` / `writeMode` / `toolMode` bound what ChatGPT can do (defaults:
  `safe` / `workspace` / `standard`). Tighten to `off` / `handoff` / `minimal`
  for read-only or plan-only use.
- codexpro shells out and inspects git; the module puts `git`, `bash`, and
  `coreutils` on the service PATH. Add more via `services.codexpro.extraPackages`.
```
