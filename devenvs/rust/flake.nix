{
  description = "Example for presentation";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    naersk = {
      url = "github:nmattia/naersk";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      rust-overlay,
      naersk,
      ...
    }:
    let
      pkgs = import nixpkgs {
        localSystem = "${system}";
        overlays = [
          (import rust-overlay)
        ];
      };
      system = "x86_64-linux";
      riscvPkgs = import nixpkgs {
        localSystem = "${system}";
        crossSystem = {
          # config = "riscv64-unknown-linux-musl";
          config = "riscv64-unknown-linux-gnu";
          # abi = "lp64";
        };
      };
      rust_build = pkgs.rust-bin.stable.latest.default.override {
        # targets = [ "riscv64gc-unknown-linux-musl" ];
        targets = [ "riscv64gc-unknown-linux-gnu" ];
        extensions = [
          "rust-src"
          "clippy"
          "cargo"
          "rustfmt-preview"
        ];
      };
      naersk_lib = naersk.lib."${system}".override {
        rustc = rust_build;
        cargo = rust_build;
      };

    in
    {
      devShell.x86_64-linux = pkgs.mkShell {
        nativeBuildInputs = [
          pkgs.qemu
          rust_build
          riscvPkgs.buildPackages.gcc
          riscvPkgs.buildPackages.gdb
        ];
      };
    };
}
