{ config, pkgs, lib, modulesPath, ... }: {

  sdImage.postBuildCommands = ''
    truncate --size=+1M "$img"
    ${pkgs.buildPackages.gptfdisk}/bin/sgdisk --mbrtogpt --attributes=2:set:2 \
      --new=3:4096:8191  --typecode=3:2E54B353-1271-4842-806F-E436D6AF6985 \
      --new=4:8192:16383 --typecode=4:5B193300-FC78-40CD-8002-E86C45580B47 \
      --sort "$img"
    eval $(partx "$img" -o START --nr 1 --pairs)
    dd conv=notrunc if=${pkgs.firmware-vf2}/u-boot-spl.bin.normal.out of="$img" seek="$START"
    eval $(partx "$img" -o START --nr 2 --pairs)
    dd conv=notrunc if=${pkgs.firmware-vf2}/u-boot.itb of="$img" seek="$START"
  '';

  boot = {
    supportedFilesystems = lib.mkForce [ "btrfs" "vfat" "f2fs" "xfs" ];
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

  virtualisation.docker.enable = true;

  environment.systemPackages = with pkgs;[ neofetch iperf3 ];

}
