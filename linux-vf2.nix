{ lib
, fetchFromGitHub
, buildLinux
, ...
} @ args:

let
  modDirVersion = "6.3.0";
in
buildLinux (args // {
  inherit modDirVersion;
  version = "${modDirVersion}-vf2";

  src = fetchFromGitHub {
    owner = "NickCao";
    repo = "linux";
    rev = "fc80774f1a7b4c8432952b20da8c30a8ab7f0ac2";
    sha256 = "sha256-f4euRON+QHNllQnU0cxl9ynOKMobys51g1ZeSKKkSv0=";
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
