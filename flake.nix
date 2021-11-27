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
                  opensbi = super.stdenv.mkDerivation rec {
                    pname = "opensbi";
                    version = "0.9";
                    src = super.fetchFromGitHub {
                      owner = "riscv";
                      repo = "opensbi";
                      rev = "v${version}";
                      sha256 = "sha256-W39R1RHsIM3yNwW/eukO+mPd9joPZLw+/XIJoH8agN8=";
                    };
                    patches = map (patch: "${self.meta-sifive}/recipes-bsp/opensbi/files/${patch}") [
                      "0001-Makefile-Don-t-specify-mabi-or-march.patch"
                    ];
                    hardeningDisable = [ "all" ];
                    makeFlags = [
                      "PLATFORM=generic"
                      "I=$(out)"
                    ];
                  };
                  uboot = super.buildUBoot rec {
                    version = "2022.01-rc2";
                    src = super.fetchFromGitHub {
                      owner = "u-boot";
                      repo = "u-boot";
                      rev = "v${version}";
                      sha256 = "sha256-74jHYazqHguPnaYisr9qfafMukIU+5+jCoZ+jXvXEUg=";
                    };
                    defconfig = "sifive_unmatched_defconfig";
                    extraPatches = map (patch: "${self.meta-sifive}/recipes-bsp/u-boot/files/riscv64/${patch}") [
                      "0001-riscv-sifive-unleashed-support-compressed-images.patch"
                      "0015-riscv-sifive-unmatched-leave-128MiB-for-ramdisk.patch"
                      "0016-riscv-sifive-unmatched-disable-FDT-and-initrd-reloca.patch"
                    ];
                    extraMakeFlags = [
                      "OPENSBI=${self.opensbi}/share/opensbi/lp64/generic/firmware/fw_dynamic.bin"
                    ];
                    filesToInstall = [ "u-boot.itb" "spl/u-boot-spl.bin" ];
                  };
                })
              ];
            };
            boot.loader = {
              grub.enable = false;
              generic-extlinux-compatible.enable = true;
            };
            boot.initrd.kernelModules = [ "nvme" "mmc_block" "mmc_spi" "spi_sifive" "spi_nor" ];
            boot.kernelParams = [ "console=ttySIF1" ];
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
            services.getty.autologinUser = "root";
          })
        ];
      };
    };
  };
}
