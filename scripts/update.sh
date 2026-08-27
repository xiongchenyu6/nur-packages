#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

echo "==> Updating flake inputs"
nix flake update

# nvchecker 要逐个查上游的最新版本,匿名调 GitHub API 只有 60 次/小时/IP,
# 而 Actions runner 的出口 IP 是共享的 —— 源一多就会被限流,查不到版本时
# nvfetcher 会静默沿用旧版本,于是"没有更新"这个结论本身就是错的。
# 本地有 keyfile.toml 就用本地的(gitignore 掉了,不会进仓库);CI 里没有,
# 就用环境里的 token 现造一个。
echo "==> Refreshing nvfetcher sources"
if [[ ! -f keyfile.toml ]]; then
  token="${NVCHECKER_GITHUB_TOKEN:-${GH_TOKEN:-${GITHUB_TOKEN:-}}}"
  if [[ -n "$token" ]]; then
    printf '[keys]\ngithub = "%s"\n' "$token" > keyfile.toml
    echo "    (用环境里的 token 生成了临时 keyfile.toml)"
  else
    echo "    警告:没有 keyfile.toml 也没有 token,nvchecker 将匿名查询,可能被限流。" >&2
  fi
fi
nvfetcher_args=(-c nvfetcher.toml -o _sources)
if [[ -f keyfile.toml ]]; then
  nvfetcher_args+=(-k keyfile.toml)
fi
nvfetcher "${nvfetcher_args[@]}"

echo "==> Rebuilding packages for updated sources"
bash ./scripts/update-changed-packages.sh
