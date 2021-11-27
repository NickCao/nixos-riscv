{
  inputs = {
    nixpkgs.url = "github:NickCao/nixpkgs/riscv";
    unmatched = {
      url = "github:zhaofengli/unmatched-nixos";
      flake = false;
    };
  };
  outputs = { self, nixpkgs, unmatched }: {
    nixosConfigurations = {
      unmatched = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ({ pkgs, lib, ... }: {
            nixpkgs = {
              crossSystem.config = "riscv64-unknown-linux-gnu";
              overlays = [
                (self: super: { linuxPackages_5_12 = super.linuxPackages_latest; })
                (import "${unmatched}/pkgs")
              ];
            };
            boot.loader = {
              grub.enable = false;
              generic-extlinux-compatible.enable = true;
            };
            fileSystems."/".device = "fake";
            services.udisks2.enable = false;
            security.polkit.enable = false;
            hardware.deviceTree.name = "sifive/hifive-unmatched-a00.dtb";
            boot.kernelPackages = pkgs.unmatched.linuxPackages;
            boot.initrd.kernelModules = [ "nvme" "mmc_block" "mmc_spi" "spi_sifive" "spi_nor" ];
          })
        ];
      };
    };
  };
}
