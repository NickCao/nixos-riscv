{ lib
, fetchFromGitHub
, buildLinux
, ...
} @ args:

let
  modDirVersion = "6.1.0";
in
buildLinux (args // {
  inherit modDirVersion;
  version = "${modDirVersion}-vf2";

  src = fetchFromGitHub {
    owner = "NickCao";
    repo = "starfive-linux";
    rev = "fa007931cc813b39146c7635ad2a1ade93b14f03";
    sha256 = "sha256-P0fJkmh9OsN59diRbOFTbqTj13wAcVnddInmgCBIGuA=";
  };

  structuredExtraConfig = with lib.kernel; {
    SOC_STARFIVE = yes;
    CLK_STARFIVE_JH7110_SYS = yes;
    RESET_STARFIVE_JH7110 = yes;
    PINCTRL_STARFIVE_JH7110 = yes;
    SERIAL_8250_DW = yes;
    MMC_DW_STARFIVE = module;
  };

  extraMeta = {
    branch = "visionfive2";
    maintainers = with lib.maintainers; [ nickcao ];
    description = "Linux kernel for StarFive's VisionFive2";
    platforms = [ "riscv64-linux" ];
  };
} // (args.argsOverride or { }))
