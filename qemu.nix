{ config, pkgs, ... }:

{
  boot = {
    loader.grub.enable = false;
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [ "console=ttyS0" "earlycon" ];
    initrd.availableKernelModules = [ "pci_host_generic" "virtio_pci" "9p" "9pnet_virtio" ];
  };

  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [ "defaults" "mode=755" ];
    };
    "/nix/store" = {
      device = "nix-store";
      fsType = "9p";
      options = [ "ro" "trans=virtio" "version=9p2000.L" "msize=1M" ];
    };
  };

  system.stateVersion = "21.11";
  networking.firewall.enable = false;
  systemd.services."autotty@hvc0".enable = false;
  services.getty.autologinUser = "root";
  systemd.services.mount-pstore.enable = false;
  virtualisation.docker.enable = true;

  system.build.vm =
    let
      qemu-path = "${pkgs.pkgsBuildBuild.qemu}/bin/qemu-system-${pkgs.targetPlatform.qemuArch}";
      closure = config.system.build.toplevel;
    in
    pkgs.writeShellScriptBin "vm" ''
      exec ${qemu-path} -M virt \
        -m 1G -smp 2 \
        -kernel ${closure}/kernel \
        -initrd ${closure}/initrd \
        -append "$(cat ${closure}/kernel-params) init=${closure}/init" \
        -device virtio-rng-pci \
        -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
        -fsdev local,security_model=passthrough,id=nix-store,path=/nix/store,readonly=on \
        -device virtio-9p-pci,id=nix-store,fsdev=nix-store,mount_tag=nix-store \
        -nographic
    '';
}
