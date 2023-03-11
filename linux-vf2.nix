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
    rev = "78db942a89fab514a6358d8ffb6324f6cbf4db44";
    sha256 = "sha256-cudsQLjjFO3kWFux1Hu47GWnV3vIwaI+dBu08KA0HMA=";
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
