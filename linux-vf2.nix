{ lib
, fetchFromGitHub
, buildLinux
, ...
} @ args:

let
  modDirVersion = "6.3.0-rc2";
in
buildLinux (args // {
  inherit modDirVersion;
  version = "${modDirVersion}-vf2";

  src = fetchFromGitHub {
    owner = "NickCao";
    repo = "linux";
    rev = "8f774c1ae2a2224b94b55f573d562dc21c3c03aa";
    sha256 = "sha256-E1CLhBLzz4HBcSbAMyaf+BlDbUO5bf41kSe7qp4fapA=";
  };

  structuredExtraConfig = with lib.kernel; {
    SERIAL_8250_DW = yes;
  };

  kernelPatches = [
    {
      name = "purgatory-fix-disabling-debug-info";
      patch = ./0001-purgatory-fix-disabling-debug-info.patch;
    }
  ];

  preferBuiltin = true;

  extraMeta = {
    branch = "visionfive2";
    maintainers = with lib.maintainers; [ nickcao ];
    description = "Linux kernel for StarFive's VisionFive2";
    platforms = [ "riscv64-linux" ];
  };
} // (args.argsOverride or { }))
