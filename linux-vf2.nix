{ lib
, fetchFromGitHub
, buildLinux
, ...
} @ args:

let
  modDirVersion = "6.3.0-rc1";
in
buildLinux (args // {
  inherit modDirVersion;
  version = "${modDirVersion}-vf2";

  src = fetchFromGitHub {
    owner = "NickCao";
    repo = "linux";
    rev = "f8cec9fc9006e294603b7e9a38c25a04e4c416f4";
    sha256 = "sha256-HQWhyT7yUa+1Qe+fFGp5m5KdO/9VmIyAjV3JT2BEbmU=";
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
