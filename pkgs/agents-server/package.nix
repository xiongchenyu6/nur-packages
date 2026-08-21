{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
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
  pythonEnv = python3.withPackages (ps: [
    ps.claude-agent-sdk
    ps.croniter
    ps.cryptography
    ps.fastapi
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
stdenvNoCC.mkDerivation (finalAttrs: {
  pname = "agents-server";
  version = "0.1.24";

  src = fetchFromGitHub {
    owner = "ZhengyiLuo";
    repo = "AgentsServer";
    tag = "v${finalAttrs.version}";
    hash = "sha256-sL0HUg79MjkN2s3OufPQ5jOC/wKlIy/rEf1r1h4k4PU=";
  };

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
    cp VERSION "$libdir/"

    makeWrapper ${pythonEnv}/bin/python $out/bin/agents-server \
      --add-flags "$libdir/agent_server.py" \
      --prefix PATH : ${runtimePath}

    runHook postInstall
  '';

  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    # Exercises the full import graph: agent_server.py pulls in the sibling
    # modules and every pyproject dependency before argparse runs.
    $out/bin/agents-server --help > /dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Self-hosted execution backend for AgentsDock, exposing Claude Code and Codex CLI over an authenticated HTTP/WebSocket API";
    homepage = "https://github.com/ZhengyiLuo/AgentsServer";
    # Upstream ships no LICENSE file and states no terms in the README, so the
    # default "all rights reserved" applies. Reclassify once upstream declares.
    license = lib.licenses.unfree;
    sourceProvenance = with lib.sourceTypes; [ fromSource ];
    platforms = lib.platforms.unix;
    mainProgram = "agents-server";
  };
})
