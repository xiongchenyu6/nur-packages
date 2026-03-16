{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.webhookAutoUpgrade;

  listenerScript =
    pkgs.writers.writePython3Bin "nixos-webhook-listener"
      {
        libraries = with pkgs.python3Packages; [
          # 目前全用标准库，留空
          # 如需异步可加 aiohttp
        ];
      }
      ''
        import http.server
        import hmac
        import hashlib
        import json
        import subprocess
        import os
        import threading

        SECRET_FILE = "${cfg.webhookSecretFile}"
        FLAKE       = "${cfg.flake}"
        BRANCH      = "${cfg.branch}"
        PORT        = ${toString cfg.port}
        FLAGS       = ${builtins.toJSON cfg.nixosRebuildFlags}

        def get_secret():
            with open(SECRET_FILE, 'r') as f:
                return f.read().strip().encode()

        def verify_signature(payload: bytes, sig_header: str) -> bool:
            if not sig_header.startswith("sha256="):
                return False
            expected = hmac.new(get_secret(), payload, hashlib.sha256).hexdigest()
            return hmac.compare_digest(expected, sig_header[7:])

        build_lock = threading.Lock()

        def run_rebuild():
            if not build_lock.acquire(blocking=False):
                print("Build already in progress, skipping.")
                return
            try:
                print(f"Starting nixos-rebuild --flake {FLAKE}")
                cmd = ["nixos-rebuild"] + FLAGS + ["--flake", FLAKE]
                result = subprocess.run(cmd)
                if result.returncode == 0:
                    print("Rebuild succeeded.")
                else:
                    print(f"Rebuild failed with code {result.returncode}")
            finally:
                build_lock.release()

        class Handler(http.server.BaseHTTPRequestHandler):
            def log_message(self, format, *args):
                print(format % args)

            def do_POST(self):
                if self.path != "/webhook":
                    self.send_response(404)
                    self.end_headers()
                    return

                length  = int(self.headers.get('Content-Length', 0))
                payload = self.rfile.read(length)
                sig     = self.headers.get('X-Hub-Signature-256', "")

                if not verify_signature(payload, sig):
                    print("Invalid signature, rejecting.")
                    self.send_response(403)
                    self.end_headers()
                    return

                try:
                    data = json.loads(payload)
                except json.JSONDecodeError:
                    self.send_response(400)
                    self.end_headers()
                    return

                ref = data.get('ref', "")
                if ref != f"refs/heads/{BRANCH}":
                    print(f"Ignoring push to {ref}")
                    self.send_response(200)
                    self.end_headers()
                    self.wfile.write(b"ignored")
                    return

                commit = data.get('after', 'unknown')[:12]
                print(f"Push detected: {commit} on {BRANCH}, triggering rebuild...")

                threading.Thread(target=run_rebuild, daemon=True).start()

                self.send_response(200)
                self.end_headers()
                self.wfile.write(b"ok")

        print(f"Listening on port {PORT}...")
        httpd = http.server.HTTPServer(('127.0.0.1', PORT), Handler)
        httpd.serve_forever()
      '';
in
{
  options.services.webhookAutoUpgrade = {
    enable = mkEnableOption "Webhook-driven NixOS auto upgrade";

    flake = mkOption {
      type = types.str;
      example = "github:kloenk/nix";
      description = "The flake URI to build";
    };

    branch = mkOption {
      type = types.str;
      default = "main";
      description = "The branch to watch for pushes";
    };

    port = mkOption {
      type = types.port;
      default = 9418;
      description = "The port for the webhook listener to bind to on localhost";
    };

    webhookSecretFile = mkOption {
      type = types.path;
      description = "File containing the GitHub webhook secret";
      example = "/run/secrets/webhook-secret";
    };

    nixosRebuildFlags = mkOption {
      type = types.listOf types.str;
      default = [ "switch" ];
      example = [
        "switch"
        "--option"
        "cores"
        "2"
      ];
      description = "Flags passed to nixos-rebuild";
    };

    nginxVirtualHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "your-host.example.com";
      description = "Configure an Nginx virtual host that proxies to the webhook listener";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.nixos-webhook-listener = {
      description = "NixOS Webhook Auto Upgrade Listener";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];
      path = [
        pkgs.nixos-rebuild
        pkgs.git
        pkgs.nix
      ];
      serviceConfig = {
        Type = "simple";
        ExecStart = "${listenerScript}/bin/nixos-webhook-listener";
        User = "root";
        Restart = "on-failure";
        RestartSec = "5s";
        Nice = 19;
        IOSchedulingClass = "idle";
      };
    };

    services.nginx.virtualHosts = mkIf (cfg.nginxVirtualHost != null) {
      "${cfg.nginxVirtualHost}" = {
        forceSSL = true;
        enableACME = true;
        locations."/webhook" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
        };
      };
    };
  };
}
