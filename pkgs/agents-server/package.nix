{
  lib,
  stdenvNoCC,
  pkgs,
  python3,
  makeWrapper,
  bash,
  coreutils,
  git,
  procps,
  tmux,
  which,
}:

# AgentsServer is the self-hosted execution backend for AgentsDock
# (https://agentsdock.net). Upstream ships `install.sh`, which creates a uv
# virtualenv and a user-level systemd/launchd unit — neither is usable on NixOS,
# so this derivation stages the plain Python sources and wraps them with an
# interpreter carrying the pyproject dependency closure.
#
# `pyproject.toml` sets `[tool.uv] package = false`: the repo is a set of
# top-level scripts, not an installable distribution. Hence mkDerivation +
# python3.withPackages rather than buildPythonPackage.
let
  sources = pkgs.callPackage ../../_sources/generated.nix { };
  pythonEnv = python3.withPackages (ps: [
    ps.claude-agent-sdk
    ps.croniter
    ps.cryptography
    ps.fastapi
    ps.httpx
    ps.pydantic
    ps.python-dateutil
    ps.python-multipart
    ps.tzdata
    ps.uvicorn
    # Upstream pins websockets>=13,<16, but the only use is reading
    # `websockets.__version__` for a diagnostics endpoint; uvicorn drives the
    # actual protocol. nixpkgs' 16.x is therefore safe.
    ps.websockets
  ]);

  # Subprocesses the server shells out to. The `claude` and `codex` CLIs are
  # deliberately absent: they carry per-user credentials, so the NixOS module
  # exposes `extraPackages` for wiring them in instead.
  runtimePath = lib.makeBinPath [
    bash
    coreutils
    git
    procps
    tmux
    which
  ];
in
stdenvNoCC.mkDerivation {
  pname = "agents-server";
  version = lib.removePrefix "v" sources.agents-server.version;
  inherit (sources.agents-server) src;

  nativeBuildInputs = [ makeWrapper ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    libdir=$out/share/agents-server
    mkdir -p "$libdir"

    # Sibling modules are imported by path, so they must land next to
    # agent_server.py. Tests and the installer scripts are not runtime inputs.
    for f in *.py; do
      case "$f" in
        test_*.py) continue ;;
      esac
      cp "$f" "$libdir/"
    done
    cp VERSION LICENSE NOTICE release-public-key.pem package.json "$libdir/"
    cp -r agentsdock_team_hub assets scripts "$libdir/"

    makeWrapper ${pythonEnv}/bin/python $out/bin/agents-server \
      --add-flags "$libdir/agent_server.py" \
      --prefix PATH : ${runtimePath}

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$TMPDIR/agents-server-test-home"
    mkdir -p "$HOME"
    # Exercises the full import graph: agent_server.py pulls in the sibling
    # modules and every pyproject dependency before argparse runs.
    $out/bin/agents-server --help > /dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Self-hosted execution backend for AgentsDock, exposing Claude Code and Codex CLI over an authenticated HTTP/WebSocket API";
    homepage = "https://github.com/ZhengyiLuo/AgentsServer";
    license = lib.licenses.asl20;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.unix;
    mainProgram = "agents-server";
  };
}
