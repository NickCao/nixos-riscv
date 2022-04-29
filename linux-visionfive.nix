{ lib
, fetchFromGitHub
, buildLinux
, ...
} @ args:

let
  modDirVersion = "5.17.1";
in
buildLinux (args // {
  inherit modDirVersion;
  version = "${modDirVersion}-visionfive";

  src = fetchFromGitHub {
    owner = "starfive-tech";
    repo = "linux";
    rev = "c5c194703d4e9541c38857ed62127a5be04fa67c";
    sha256 = "02nxakn4xvrqwrssz1iipyphzsnfxx8nz4adqx2p2gn6fdhx1ryy";
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
    branch = "visionfive-5.17.y";
    maintainers = with lib.maintainers; [ Madouura zhaofengli ius ];
    description = "Linux kernel for StarFive's JH7100 RISC-V SoC (VisionFive)";
    platforms = [ "riscv64-linux" ];
    hydraPlatforms = [ "riscv64-linux" ];
  };
} // (args.argsOverride or { }))
