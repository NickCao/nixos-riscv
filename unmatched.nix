{ config, pkgs, lib, modulesPath, ... }: {
  boot.supportedFilesystems = lib.mkForce [ "btrfs" "vfat" "f2fs" "xfs" ];
  boot.initrd.kernelModules = [ "nvme" "mmc_block" "mmc_spi" "spi_sifive" "spi_nor" "uas" "sdhci_pci" ];
  boot.kernelParams = [ "console=ttySIF1" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.kernelPatches = map (patch: { name = patch; patch = "${pkgs.meta-sifive}/recipes-kernel/linux/files/${patch}"; }) [
    "0001-riscv-sifive-fu740-cpu-1-2-3-4-set-compatible-to-sif.patch"
    "0002-riscv-sifive-unmatched-define-PWM-LEDs.patch"
    "0003-Revert-riscv-dts-sifive-unmatched-Link-the-tmp451-wi.patch"
  ] ++ [{
    name = "sifive";
    patch = null;
    extraConfig = ''
      SOC_SIFIVE y
      PCIE_FU740 y
      PWM_SIFIVE y
      EDAC_SIFIVE y
      SIFIVE_L2 y
    '';
  }];
  services.getty.autologinUser = "root";
  services.openssh.enable = true;
  environment.systemPackages = with pkgs; [
    neofetch
    mtdutils
    lm_sensors
    # waypipe
    pciutils
    glxinfo
    radeontop
    iperf3
    gdb
  ];
  networking.wireless.iwd.enable = true;
  hardware.firmware = with pkgs; [ firmwareLinuxNonfree ];
  hardware.opengl.enable = true;
  # programs.sway.enable = true;
  users = {
    mutableUsers = false;
    users = {
      root.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOLQwaWXeJipSuAB+lV202yJOtAgJSNzuldH7JAf2jji" ];
    };
  };
}
