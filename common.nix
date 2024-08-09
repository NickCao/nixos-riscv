{ config, modulesPath, ... }:
{

  imports = [
    "${modulesPath}/profiles/base.nix"
    "${modulesPath}/installer/sd-card/sd-image.nix"
  ];

  nixpkgs = {
    localSystem.config = "x86_64-unknown-linux-gnu";
    crossSystem.config = "riscv64-unknown-linux-gnu";
  };

  nixpkgs.flake = {
    setNixPath = false;
    setFlakeRegistry = false;
  };

  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };

  programs.less.lessopen = null;

  sdImage = {
    populateFirmwareCommands = "";
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';
  };

}
