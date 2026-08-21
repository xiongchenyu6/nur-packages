let
  # Every template is a flake-parts flake exposing a devShell (plus a NixOS
  # configuration in the `nixos` one), with a matching .envrc for direnv.
  praise = what: "A grossly incandescent and minimal ${what}";
in
rec {
  default = empty;

  empty = {
    path = ./empty;
    description = praise "flake with a bare dev shell";
  };
  java = {
    path = ./java;
    description = praise "Java dev shell";
  };
  nodejs = {
    path = ./nodejs;
    description = praise "Node.js dev shell, with corepack shims";
  };
  bun = {
    path = ./bun;
    description = praise "Bun dev shell";
  };
  python = {
    path = ./python;
    description = praise "Python dev shell, with a virtualenv bootstrap";
  };
  rust = {
    path = ./rust;
    description = praise "Rust dev shell";
  };
  cc = {
    path = ./cc;
    description = praise "C/C++ dev shell, on clang with cmake and bear";
  };
  go = {
    path = ./go;
    description = praise "Go dev shell";
  };
  shell = {
    path = ./shell;
    description = praise "shell-scripting dev shell";
  };
  cuda = {
    path = ./cuda;
    description = praise "CUDA dev shell";
  };
  terraform = {
    path = ./terraform;
    description = praise "Terraform dev shell";
  };
  tenv = {
    path = ./tenv;
    description = praise "tenv dev shell, for multi-version Terraform";
  };
  nixos = {
    path = ./nixos;
    description = praise "NixOS host flake, with home-manager wired in";
  };
  zig = {
    path = ./zig;
    description = praise "Zig dev shell";
  };
}
