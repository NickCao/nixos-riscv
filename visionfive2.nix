{ config, pkgs, lib, modulesPath, ... }: {

  sdImage = {
    populateFirmwareCommands = "";
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';
  };

  boot = {
    supportedFilesystems = lib.mkForce [ "btrfs" "vfat" "f2fs" "xfs" ];
    loader = {
      grub.enable = false;
      generic-extlinux-compatible.enable = true;
    };
    kernelPackages = pkgs.linuxPackagesFor (pkgs.callPackage ./linux-vf2.nix { kernelPatches = [ ]; });
    kernelParams = [
      "console=tty0"
      "console=ttyS0,115200"
      "earlycon=sbi"
    ];
  };

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
