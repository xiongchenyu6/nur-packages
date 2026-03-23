#!/usr/bin/env bash

set -euo pipefail

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
cd "$repo_root"

max_retries="${MAX_HASH_UPDATE_RETRIES:-6}"

escape_regex() {
  printf '%s' "$1" | sed -e 's/[][(){}.^$*+?|\\]/\\&/g'
}

resolve_attr_from_file() {
  local package_file="$1"

  case "$package_file" in
    pkgs/emacs/*/package.nix)
      local package_name="${package_file#pkgs/emacs/}"
      package_name="${package_name%/package.nix}"
      printf 'emacs-%s\n' "$package_name"
      ;;
    pkgs/*/package.nix)
      local package_name="${package_file#pkgs/}"
      package_name="${package_name%/package.nix}"
      printf '%s\n' "$package_name"
      ;;
    *)
      return 1
      ;;
  esac
}

collect_changed_sources() {
  local previous_sources
  previous_sources="$(mktemp)"

  if git cat-file -e HEAD:_sources/generated.json 2>/dev/null; then
    git show HEAD:_sources/generated.json >"$previous_sources"
  else
    printf '{}\n' >"$previous_sources"
  fi

  jq -nr \
    --slurpfile old "$previous_sources" \
    --slurpfile new "_sources/generated.json" \
    '
      (((($old[0] // {}) | keys) + (($new[0] // {}) | keys)) | unique | .[]) as $key
      | select((($old[0] // {})[$key] // null) != (($new[0] // {})[$key] // null))
      | $key
    '

  rm -f "$previous_sources"
}

build_attr() {
  local attr_name="$1"
  local expr

  expr="$(
    cat <<EOF
let
  flake = builtins.getFlake "path:${repo_root}";
  pkgs = import flake.inputs.nixpkgs {
    system = builtins.currentSystem;
    overlays = [ flake.outputs.overlays.default ];
    config.allowUnfree = true;
  };
in
builtins.getAttr "${attr_name}" pkgs
EOF
  )"

  nix build --accept-flake-config --no-link --impure --expr "$expr"
}

extract_hash_pair() {
  local build_output="$1"
  local current_hash new_hash

  current_hash="$(
    printf '%s\n' "$build_output" \
      | sed -nE 's/.*(specified|wanted):[[:space:]]*(sha256-[A-Za-z0-9+/=]+).*/\2/p' \
      | tail -n1
  )"
  new_hash="$(
    printf '%s\n' "$build_output" \
      | sed -nE 's/.*got:[[:space:]]*(sha256-[A-Za-z0-9+/=]+).*/\1/p' \
      | tail -n1
  )"

  if [[ -n "$current_hash" && -n "$new_hash" && "$current_hash" != "$new_hash" ]]; then
    printf '%s\t%s\n' "$current_hash" "$new_hash"
  fi
}

replace_hash_in_file() {
  local package_file="$1"
  local current_hash="$2"
  local new_hash="$3"

  if ! rg -q --fixed-strings "$current_hash" "$package_file"; then
    echo "Could not find ${current_hash} in ${package_file}" >&2
    return 1
  fi

  OLD_HASH="$current_hash" NEW_HASH="$new_hash" perl -0pi -e 's/\Q$ENV{OLD_HASH}\E/$ENV{NEW_HASH}/' "$package_file"
}

refresh_target() {
  local attr_name="$1"
  local package_file="${2:-}"
  local attempt=1
  local build_output hash_pair current_hash new_hash

  while (( attempt <= max_retries )); do
    echo "Building ${attr_name} (attempt ${attempt}/${max_retries})"

    if build_output="$(build_attr "$attr_name" 2>&1)"; then
      echo "Built ${attr_name}"
      return 0
    fi

    if [[ -z "$package_file" ]]; then
      printf '%s\n' "$build_output" >&2
      return 1
    fi

    hash_pair="$(extract_hash_pair "$build_output" || true)"
    if [[ -z "$hash_pair" ]]; then
      printf '%s\n' "$build_output" >&2
      return 1
    fi

    IFS=$'\t' read -r current_hash new_hash <<<"$hash_pair"
    echo "Updating ${package_file}: ${current_hash} -> ${new_hash}"
    replace_hash_in_file "$package_file" "$current_hash" "$new_hash"
    attempt=$((attempt + 1))
  done

  echo "Exceeded hash refresh retries for ${attr_name}" >&2
  return 1
}

declare -a changed_sources=()
changed_sources_output="$(collect_changed_sources)"
if [[ -n "$changed_sources_output" ]]; then
  mapfile -t changed_sources <<<"$changed_sources_output"
fi

if [[ "${#changed_sources[@]}" -eq 0 ]]; then
  echo "No nvfetcher source changes detected"
  exit 0
fi

printf 'Changed sources: %s\n' "${changed_sources[*]}"

declare -A target_files=()

for source_name in "${changed_sources[@]}"; do
  escaped_source_name="$(escape_regex "$source_name")"

  while IFS= read -r package_file; do
    [[ -z "$package_file" ]] && continue

    if attr_name="$(resolve_attr_from_file "$package_file" 2>/dev/null)"; then
      target_files["$attr_name"]="$package_file"
    fi
  done < <(rg -l "sources\\.${escaped_source_name}\\b" pkgs || true)

  case "$source_name" in
    librime-lua)
      target_files["librime"]=""
      ;;
  esac
done

if [[ "${#target_files[@]}" -eq 0 ]]; then
  echo "No build targets found for updated sources"
  exit 0
fi

echo "Build targets:"
for attr_name in "${!target_files[@]}"; do
  if [[ -n "${target_files[$attr_name]}" ]]; then
    echo "  - ${attr_name} (${target_files[$attr_name]})"
  else
    echo "  - ${attr_name}"
  fi
done

for attr_name in "${!target_files[@]}"; do
  refresh_target "$attr_name" "${target_files[$attr_name]}"
done
