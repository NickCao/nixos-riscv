{
  description = "RISC-V Linux cross-compilation dev shell";

  inputs = {
    nixpkgs.url = "github:NickCao/nixpkgs/riscv";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

        crossPkgs = pkgs.pkgsCross.riscv64;
      in
      {
        devShells.default = pkgs.mkShell {
          name = "riscv-linux-dev-shell";

          buildInputs = [
            crossPkgs.stdenv.cc
            pkgs.qemu
          ];

          shellHook = ''
            echo "RISC-V Linux (glibc) dev shell ready."
            echo "Use riscv64-unknown-linux-gnu-gcc to compile."
          '';
        };
      }
    );
}
