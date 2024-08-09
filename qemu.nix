{
  config,
  pkgs,
  lib,
  ...
}:

{
  boot = {
    loader.grub.enable = false;
    kernelPackages = pkgs.linuxPackages_latest;
    kernelParams = [
      "console=ttyS0"
      "earlycon"
    ];
    initrd.availableKernelModules = [
      "pci_host_generic"
      "virtio_pci"
      "9p"
      "9pnet_virtio"
    ];
  };

  fileSystems = lib.mkForce {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [
        "defaults"
        "mode=755"
      ];
    };
    "/nix/store" = {
      device = "nix-store";
      fsType = "9p";
      options = [
        "ro"
        "trans=virtio"
        "version=9p2000.L"
        "msize=1M"
      ];
    };
  };

  system.stateVersion = "21.11";
  networking.firewall.enable = false;
  systemd.services."autotty@hvc0".enable = false;
  services.getty.autologinUser = "root";
  systemd.services.mount-pstore.enable = false;

  services.xserver.desktopManager.gnome.enable = true;
  services.xserver.displayManager.gdm.enable = true;
  services.displayManager.enable = true;

  services.gnome.core-utilities.enable = lib.mkForce false;
  services.gnome.core-developer-tools.enable = lib.mkForce false;
  services.gnome.gnome-remote-desktop.enable = false;
  services.gnome.gnome-user-share.enable = false;
  services.gnome.gnome-online-miners.enable = lib.mkForce false;
  services.power-profiles-daemon.enable = false;
  services.gnome.gnome-initial-setup.enable = false;
  services.gnome.evolution-data-server.enable = lib.mkForce false;

  services.gnome.gnome-browser-connector.enable = false;
  networking.networkmanager.enable = false;
  networking.wireless.enable = false;
  xdg.portal.enable = lib.mkForce false;
  fonts.packages = lib.mkForce [ ];

  environment.gnome.excludePackages = [
    pkgs.gnome.gnome-control-center
    pkgs.gnome-tour
    pkgs.orca
  ];

  services.displayManager.autoLogin = {
    enable = true;
    user = "alice";
  };

  environment.systemPackages = [
    pkgs.xterm
    pkgs.firefox
  ];

  users.users.alice = {
    isNormalUser = true;
    description = "Alice Foobar";
    password = "foobar";
    uid = 1000;
  };

  system.build.vm =
    let
      qemu-path = "${pkgs.pkgsBuildBuild.qemu}/bin/qemu-system-${pkgs.targetPlatform.qemuArch}";
      closure = config.system.build.toplevel;
    in
    pkgs.writeShellScriptBin "vm" ''
      exec ${qemu-path} -M virt \
        -m 8G -smp 4 \
        -kernel ${closure}/kernel \
        -initrd ${closure}/initrd \
        -append "$(cat ${closure}/kernel-params) init=${closure}/init" \
        -device virtio-rng-pci \
        -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
        -fsdev local,security_model=passthrough,id=nix-store,path=/nix/store,readonly=on \
        -device virtio-9p-pci,id=nix-store,fsdev=nix-store,mount_tag=nix-store \
        -device virtio-gpu-gl \
        -device qemu-xhci -usb -device usb-kbd -device usb-tablet \
        -display gtk,gl=on,show-cursor=on
    '';
}
