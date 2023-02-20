{ config, pkgs, lib, modulesPath, ... }: {

  boot = {
    kernelPackages = pkgs.linuxPackagesFor (pkgs.callPackage ./linux-vf2.nix { kernelPatches = [ ]; });
    kernelParams = [
      "console=tty0"
      "console=ttyS0,115200"
      "earlycon=sbi"
    ];
    initrd.kernelModules = [ "dw_mmc-starfive" ];
  };

  hardware.deviceTree.name = "starfive/jh7110-starfive-visionfive-v2.dtb";

  services = {
    getty.autologinUser = "root";
    openssh = {
      enable = true;
      settings.PermitRootLogin = "yes";
    };
  };

  users = {
    mutableUsers = false;
    users.root.password = "passwd";
  };

  environment.systemPackages = with pkgs;[ neofetch ];

}
