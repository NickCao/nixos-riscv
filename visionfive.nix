{ config, pkgs, lib, modulesPath, ... }: {
  nixpkgs = {
    crossSystem.config = "riscv64-unknown-linux-gnu";
    config = {
      allowUnfree = true;
      allowBroken = true;
    };
  };
  sdImage = {
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';
    populateFirmwareCommands = "";
  };
  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };
  hardware.deviceTree.name = "starfive/jh7100-starfive-visionfive-v1.dtb";
    boot.kernelParams = [
    "console=tty0" "console=ttyS0,115200" "earlycon=sbi"
    # https://github.com/starfive-tech/linux/issues/14
    "stmmac.chain_mode=1"
  ];
  boot.initrd.kernelModules = [ "dw_mmc-pltfm" "spi-dw-mmio" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPatches = [{
    name = "visionfive";
    patch = null;
    structuredExtraConfig = with pkgs.lib.kernel; {
      SOC_STARFIVE = yes;
      SERIAL_8250_DW = yes;
      PINCTRL_STARFIVE = yes;
      DW_AXI_DMAC_STARFIVE = yes;
      PTP_1588_CLOCK = yes;
      STMMAC_ETH = yes;
      STMMAC_PCI = yes;
    };
  }];
  services.getty.autologinUser = "root";
  services.openssh.enable = true;
  users = {
    mutableUsers = false;
    users = {
      root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLQwaWXeJipSuAB+lV202yJOtAgJSNzuldH7JAf2jji" ];
    };
  };
}
