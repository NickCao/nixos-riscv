{ lib
, fetchFromGitHub
, buildLinux
, ...
} @ args:

let
  modDirVersion = "6.4.0-rc2";
in
buildLinux (args // {
  inherit modDirVersion;
  version = "${modDirVersion}-vf2";

  src = fetchFromGitHub {
    owner = "NickCao";
    repo = "linux";
    rev = "f4be6cc5d56d372f05ddc1b2a0745f8bd2af9bbf";
    sha256 = "sha256-tmgvyE92YdnH2G1sE61ZInKPuDogdSjp8KRy6OHYatQ=";
  };

  structuredExtraConfig = with lib.kernel; {
    SERIAL_8250_DW = yes;
    PL330_DMA = no;
  };

  kernelPatches = [ ];

  preferBuiltin = true;

  extraMeta = {
    branch = "visionfive2";
    maintainers = with lib.maintainers; [ nickcao ];
    description = "Linux kernel for StarFive's VisionFive2";
    platforms = [ "riscv64-linux" ];
  };
} // (args.argsOverride or { }))
