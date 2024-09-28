{ ... }:
{

  nixpkgs = {
    buildPlatform.config = "x86_64-unknown-linux-gnu";
    hostPlatform.config = "riscv64-unknown-linux-gnu";
  };

  nixpkgs.flake = {
    setNixPath = false;
    setFlakeRegistry = false;
  };

}
