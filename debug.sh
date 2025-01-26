#!/usr/bin/env bash

# Get current system
SYSTEM=$(nix eval --raw --impure --expr 'builtins.currentSystem')

# Print all available overlay packages
echo "Available overlay packages:"
nix flake show --json \
  | jq -r ".packages.\"${SYSTEM}\" | keys[]" 2>/dev/null \
  || echo "Error: Could not evaluate packages"

# Print detailed package info
if [ -n "$1" ]; then
  echo -e "\nPackage details for $1:"
  nix flake show --json \
    | jq ".packages.\"${SYSTEM}\".\"$1\"" 2>/dev/null \
    || echo "Error: Package $1 not found"
fi
