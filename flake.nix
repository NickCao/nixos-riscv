{
  inputs = {
    nixpkgs.url = "github:NickCao/nixpkgs/riscv";
  };
  outputs = { self, nixpkgs }: {
    nixosConfigurations = {
      unmatched = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ({ config, pkgs, lib, modulesPath, ... }: {
            imports = [ "${modulesPath}/installer/sd-card/sd-image.nix" ];
            disabledModules = [ "profiles/all-hardware.nix" ];
            sdImage = {
              populateRootCommands = ''
                mkdir -p ./files/boot
                ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
              '';
              populateFirmwareCommands = "";
            };
            nixpkgs = {
              crossSystem.config = "riscv64-unknown-linux-gnu";
              overlays = [
                (self: super: {
                  meta-sifive = super.fetchFromGitHub {
                    owner = "sifive";
                    repo = "meta-sifive";
                    rev = "2021.10.00";
                    sha256 = "sha256-TDlrAOOoK+3k/J1gDT1CkbxlfGfhSayZEzIjG1L3iPY=";
                  };
                })
              ];
            };
            boot.loader = {
              grub.enable = false;
              generic-extlinux-compatible.enable = true;
            };
            boot.initrd.kernelModules = [ "nvme" "mmc_block" "mmc_spi" "spi_sifive" "spi_nor" ];
            boot.kernelPackages = pkgs.linuxPackages_latest;
            boot.kernelPatches = map (patch: { name = patch; patch = "${pkgs.meta-sifive}/recipes-kernel/linux/files/${patch}"; }) [
              "0001-riscv-sifive-fu740-cpu-1-2-3-4-set-compatible-to-sif.patch"
              "0002-riscv-sifive-unmatched-update-regulators-values.patch"
              "0003-riscv-sifive-unmatched-define-PWM-LEDs.patch"
              "0004-riscv-sifive-unmatched-add-gpio-poweroff-node.patch"
              "0005-SiFive-HiFive-Unleashed-Add-PWM-LEDs-D1-D2-D3-D4.patch"
              "0006-riscv-sifive-unleashed-define-opp-table-cpufreq.patch"
            ] ++ [{
              name = "sifive";
              patch = null;
              extraConfig = ''
                SOC_SIFIVE y
                PCIE_FU740 y
                PWM_SIFIVE y
                EDAC_SIFIVE y
                SIFIVE_L2 y
                RISCV_ERRATA_ALTERNATIVE y
                ERRATA_SIFIVE y
                ERRATA_SIFIVE_CIP_453 y
                ERRATA_SIFIVE_CIP_1200 y
              '';
            }];
            services.udisks2.enable = false;
            security.polkit.enable = false;
          })
        ];
      };
    };
  };
}
