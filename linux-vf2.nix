{ lib
, fetchFromGitHub
, buildLinux
, ...
} @ args:

let
  modDirVersion = "6.2.0";
in
buildLinux (args // {
  inherit modDirVersion;
  version = "${modDirVersion}-vf2";

  src = fetchFromGitHub {
    owner = "NickCao";
    repo = "linux";
    rev = "3356b42a7c04e070ceec5d2163fe18d2bb4a3616";
    sha256 = "sha256-4eymHM3TR3K4+zK7HtokmyiCFSRiMG0IgOv3AMp4kCY=";
  };

  structuredExtraConfig = with lib.kernel; {
    SERIAL_8250_DW = yes;
  };

  preferBuiltin = true;

  extraMeta = {
    branch = "visionfive2";
    maintainers = with lib.maintainers; [ nickcao ];
    description = "Linux kernel for StarFive's VisionFive2";
    platforms = [ "riscv64-linux" ];
  };
} // (args.argsOverride or { }))
