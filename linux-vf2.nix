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
    owner = "esmil";
    repo = "linux";
    rev = "6ba2b4f6ff44e2c992ed4fdbce9e9d20b945bba9";
    sha256 = "sha256-XJPu9GTaXJiy9ZRcvtURQ9wu67uaJruxCIvwPd1e01g=";
  };

  structuredExtraConfig = with lib.kernel; {
    SOC_STARFIVE = yes;
    PINCTRL_STARFIVE_JH7110_SYS = yes;
    PINCTRL_STARFIVE_JH7110_AON = yes;
    CLK_STARFIVE_JH7110_AON = yes;
    SERIAL_8250_DW = yes;
    MMC_DW_STARFIVE = module;
  };

  extraMeta = {
    branch = "jh7110";
    maintainers = with lib.maintainers; [ nickcao ];
    description = "Linux kernel for StarFive's VisionFive2";
    platforms = [ "riscv64-linux" ];
  };
} // (args.argsOverride or { }))
