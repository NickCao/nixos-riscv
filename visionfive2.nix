{ config, pkgs, lib, modulesPath, ... }: {

  boot = {
    supportedFilesystems = lib.mkForce [ "btrfs" "vfat" "f2fs" "xfs" ];
    kernelPackages = pkgs.linuxPackagesFor (pkgs.callPackage ./linux-vf2.nix { kernelPatches = [ ]; });
    kernelParams = [
      "console=tty0"
      "console=ttyS0,115200"
      "earlycon=sbi"
    ];
  };

  hardware.deviceTree.name = "starfive/jh7110-starfive-visionfive-v2.dtb";

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
