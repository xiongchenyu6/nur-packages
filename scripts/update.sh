#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

echo "==> Updating flake inputs"
nix flake update

echo "==> Refreshing nvfetcher sources"
nvfetcher_args=(-c nvfetcher.toml -o _sources)
if [[ -f keyfile.toml ]]; then
  nvfetcher_args+=(-k keyfile.toml)
fi
nvfetcher "${nvfetcher_args[@]}"

echo "==> Rebuilding packages for updated sources"
bash ./scripts/update-changed-packages.sh
