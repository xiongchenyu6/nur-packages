
# SPDX-FileCopyrightText: 2021 Serokell <https://serokell.io/>
#
# SPDX-License-Identifier: CC0-1.0
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = { nixpkgs, flake-parts, ... }@inputs:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" "aarch64-darwin" "x86_64-darwin" ];
      perSystem = { config, self', inputs', pkgs, system, lib, ... }: {
        devShells.default =
          pkgs.mkShell {          
            buildInputs = with pkgs; [             nixfmt-rfc-style
            nil
              git gitRepo gnupg autoconf curl
              procps gnumake util-linux m4 gperf unzip
              cudatoolkit linuxPackages.nvidia_x11
              libGLU libGL
              xorg.libXi xorg.libXmu freeglut
              xorg.libXext xorg.libX11 xorg.libXv xorg.libXrandr zlib 
              ncurses5 stdenv.cc binutils
            ];
            shellHook = ''
               export CUDA_PATH=${pkgs.cudatoolkit}
               # export LD_LIBRARY_PATH=${pkgs.linuxPackages.nvidia_x11}/lib:${pkgs.ncurses5}/lib
               export EXTRA_LDFLAGS="-L/lib -L${pkgs.linuxPackages.nvidia_x11}/lib"
               export EXTRA_CCFLAGS="-I/usr/include"
            '';    
          };
      };
    };
}
