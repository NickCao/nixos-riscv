{ config, pkgs, lib, modulesPath, ... }: {
  boot = {
    supportedFilesystems = lib.mkForce [ "btrfs" "vfat" "f2fs" "xfs" ];
    kernelPackages = pkgs.linuxPackagesFor (pkgs.callPackage ./linux-visionfive.nix {
      kernelPatches = with pkgs.kernelPatches; [
        bridge_stp_helper
        request_key_helper
      ];
    });
    kernelParams = [
      "console=tty0"
      "console=ttyS0,115200"
      "earlycon=sbi"
      # https://github.com/starfive-tech/linux/issues/14
      "stmmac.chain_mode=1"
    ];
    initrd.kernelModules = [ "dw-axi-dmac-platform" "dw_mmc-pltfm" "spi-dw-mmio" ];
  };
  hardware.deviceTree.name = "starfive/jh7100-starfive-visionfive-v1.dtb";
  systemd.services."serial-getty@hvc0".enable = false;
  services = {
    getty.autologinUser = "root";
    openssh = {
      enable = true;
      permitRootLogin = "yes";
    };
  };
  users = {
    mutableUsers = false;
    users.root.password = "passwd";
  };
  environment.systemPackages = with pkgs;[ neofetch ];
}
