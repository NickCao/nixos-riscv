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
    fsType = "virtiofs";
    neededForBoot = true;
    options = [ "ro" ];
  };

  boot.initrd.availableKernelModules = [
    "virtiofs"
    "virtio_pci"
    "pci_host_generic"
  ];
  system.stateVersion = "21.11";
  networking.firewall.enable = false;
  systemd.services."autotty@hvc0".enable = false;
  services.getty.autologinUser = "root";
  security.polkit.enable = false;
  services.udisks2.enable = false;
  systemd.services.mount-pstore.enable = false;
  virtualisation.docker.enable = true;

  system.build.vm =
    let
      qemu-path = "qemu-system-${pkgs.targetPlatform.qemuArch}";
      closure = config.system.build.toplevel;
    in
    pkgs.writeShellScriptBin "minimal-vm" ''
      virtiofsd --socket-path /tmp/fs.sock --shared-dir /nix/store/ &
      exec ${qemu-path} -M virt -m 4G -smp 8 \
        -device virtio-rng-pci \
        -kernel ${closure}/kernel \
        -initrd ${closure}/initrd \
        -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
        -append "$(cat ${closure}/kernel-params) init=${closure}/init" \
        -chardev socket,id=char0,path=/tmp/fs.sock \
        -device vhost-user-fs-pci,chardev=char0,tag=nix-store \
        -object memory-backend-memfd,id=mem,size=4G,share=on \
        -numa node,memdev=mem \
        -nographic "$@"
    '';
}
