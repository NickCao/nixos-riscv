{ config, lib, pkgs, modulesPath, ... }:

{
  boot.loader.grub.enable = false;
  boot.kernelParams = [ "console=ttyS0" "earlycon" ];
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "quicksand";

  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "defaults" "size=256M" "mode=755" ];
  };

  fileSystems."/nix/store" = {
    device = "nix-store";
    fsType = "9p";
    neededForBoot = true;
    options = [ "defaults" "ro" "trans=virtio" "msize=16384" ];
  };

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "9p"
    "9pnet_virtio"
    "pci_host_generic"
  ];

  system.stateVersion = "21.11";

  networking.dhcpcd.enable = false;
  networking.firewall.enable = false;

  systemd.services."autotty@hvc0".enable = false;

  services.getty.autologinUser = "root";
  security.polkit.enable = false;
  services.udisks2.enable = false;

  system.build.vm =
    let
      qemu-path = "qemu-system-${pkgs.targetPlatform.qemuArch}";
      closure = config.system.build.toplevel;
    in
    pkgs.writeShellScriptBin "minimal-vm" ''
      exec ${qemu-path} -M virt \
        -device virtio-rng-pci \
        -kernel ${closure}/kernel \
        -initrd ${closure}/initrd \
        -append "$(cat ${closure}/kernel-params) init=${closure}/init" \
        -fsdev local,security_model=passthrough,id=nix-store,path=/nix/store,readonly=on \
        -device virtio-9p-pci,id=nix-store,fsdev=nix-store,mount_tag=nix-store,bus=pcie.0 \
        -nographic "$@"
    '';
}
