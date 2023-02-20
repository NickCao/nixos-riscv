{ lib
, fetchFromGitHub
, buildLinux
, ...
} @ args:

let
  modDirVersion = "6.1.12";
in
buildLinux (args // {
  inherit modDirVersion;
  version = "${modDirVersion}-vf2";

  src = fetchFromGitHub {
    owner = "NickCao";
    repo = "starfive-linux";
    rev = "bffbafbf52cc052621daaaa43a378eb5d73a018b";
    sha256 = "sha256-ZQoBJzbylctH2tewfYoKKkjgES6d5xrqEvv3TTpOQgA=";
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
