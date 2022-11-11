{ lib
, fetchFromGitHub
, buildLinux
, ...
} @ args:

let
  modDirVersion = "5.19.17";
in
buildLinux (args // {
  inherit modDirVersion;
  version = "${modDirVersion}-visionfive";

  src = fetchFromGitHub {
    owner = "starfive-tech";
    repo = "linux";
    rev = "5069561e5a4ed972dd23d2b40ff7de27feb68707";
    sha256 = "sha256-s3kpJ0U4oThKb6nc5ZieEDR0IZYiIony0Ca+Ix4/41s=";
  };

  defconfig = "starfive_jh7100_fedora_defconfig";

  structuredExtraConfig = with lib.kernel; {
    SERIAL_8250_DW = yes;
    PINCTRL_STARFIVE = yes;

    # Doesn't build as a module
    DW_AXI_DMAC_STARFIVE = yes;

    # stmmac hangs when built as a module
    PTP_1588_CLOCK = yes;
    STMMAC_ETH = yes;
    STMMAC_PCI = yes;
  };

  extraMeta = {
    branch = "visionfive-5.19.y";
    maintainers = with lib.maintainers; [ Madouura zhaofengli ius ];
    description = "Linux kernel for StarFive's JH7100 RISC-V SoC (VisionFive)";
    platforms = [ "riscv64-linux" ];
    hydraPlatforms = [ "riscv64-linux" ];
  };
} // (args.argsOverride or { }))
